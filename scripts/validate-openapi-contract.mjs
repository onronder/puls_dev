#!/usr/bin/env node
/**
 * PR12.2 OpenAPI contract validation + PR12.4 examples/error catalog — Node built-ins only, no YAML parser.
 */
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const OPENAPI_PATH = path.join(root, 'docs/api/openapi.yaml')
const INVENTORY_PATH = path.join(root, 'docs/data/12_app_api_boundary_inventory.md')
const ALLOWLIST_PATH = path.join(root, 'docs/api/openapi-contract-allowlist.json')
const EXAMPLES_PATH = path.join(root, 'docs/api/openapi-examples.yaml')

const failures = []

function fail(message) {
  failures.push(message)
}

function readFile(filePath) {
  if (!fs.existsSync(filePath)) {
    fail(`missing required file: ${path.relative(root, filePath)}`)
    return ''
  }
  return fs.readFileSync(filePath, 'utf8')
}

function sliceSection(content, startKey, endKeys) {
  const startIdx = content.indexOf(`${startKey}\n`)
  if (startIdx === -1) {
    fail(`missing section: ${startKey}`)
    return ''
  }
  const afterStart = content.slice(startIdx + startKey.length + 1)
  let endIdx = afterStart.length
  for (const endKey of endKeys) {
    const idx = afterStart.indexOf(`${endKey}\n`)
    if (idx !== -1 && idx < endIdx) {
      endIdx = idx
    }
  }
  return afterStart.slice(0, endIdx)
}

function extractOperationBlocks(pathsSection) {
  const blocks = new Map()
  const lines = pathsSection.split('\n')
  let currentId = null
  let currentLines = []

  for (const line of lines) {
    const match = line.match(/^      operationId: ([A-Za-z0-9]+)$/)
    if (match) {
      if (currentId) {
        blocks.set(currentId, currentLines.join('\n'))
      }
      currentId = match[1]
      currentLines = [line]
      continue
    }
    if (currentId) {
      currentLines.push(line)
    }
  }
  if (currentId) {
    blocks.set(currentId, currentLines.join('\n'))
  }
  return blocks
}

function extractLineValue(block, key) {
  const re = new RegExp(`^      ${key}: (.+)$`, 'm')
  const match = block.match(re)
  return match ? match[1].trim() : null
}

function extractRequestSchemaRef(block) {
  if (!/requestBody:/.test(block)) {
    return null
  }
  const match = block.match(/\$ref: '#\/components\/schemas\/([A-Za-z0-9]+)'/)
  return match ? match[1] : null
}

function extractSchemaProperties(schemasSection, schemaName) {
  const lines = schemasSection.split('\n')
  let inSchema = false
  let inProperties = false
  const properties = []

  for (const line of lines) {
    if (line === `    ${schemaName}:`) {
      inSchema = true
      inProperties = false
      continue
    }
    if (inSchema && /^    [A-Za-z0-9]+:/.test(line) && line !== `    ${schemaName}:`) {
      break
    }
    if (inSchema && line === '      properties:') {
      inProperties = true
      continue
    }
    if (inSchema && inProperties) {
      const propMatch = line.match(/^        ([A-Za-z0-9]+):/)
      if (propMatch) {
        properties.push(propMatch[1])
        continue
      }
      if (/^      [A-Za-z]/.test(line) && !line.startsWith('        ')) {
        inProperties = false
      }
    }
  }

  return properties
}

function extractRequestSchemaBlocks(schemasSection) {
  const blocks = []
  const lines = schemasSection.split('\n')
  let current = null
  let buffer = []

  for (const line of lines) {
    const match = line.match(/^    ([A-Za-z0-9]+Request):$/)
    if (match) {
      if (current) {
        blocks.push({ name: current, text: buffer.join('\n') })
      }
      current = match[1]
      buffer = [line]
      continue
    }
    if (current) {
      if (/^    [A-Za-z0-9]+:/.test(line) && !line.startsWith('      ')) {
        blocks.push({ name: current, text: buffer.join('\n') })
        current = null
        buffer = []
        continue
      }
      buffer.push(line)
    }
  }
  if (current) {
    blocks.push({ name: current, text: buffer.join('\n') })
  }
  return blocks
}

function extractAppendixRoutes(content) {
  const section = sliceSection(content, 'x-puls-read-models:', [
    'x-puls-internal-backend-surfaces:',
    'x-puls-not-exposed:',
  ])
  const routes = []
  for (const line of section.split('\n')) {
    const match = line.match(/^  - route: (.+)$/)
    if (match) {
      routes.push(match[1].trim())
    }
  }
  return routes
}

function countExactNeedle(content, needle) {
  const escaped = needle.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const re = new RegExp(`^[ \\t]+operationId:[ \\t]+${escaped}$`, 'gm')
  return (content.match(re) ?? []).length
}

function countSubstring(content, needle) {
  let count = 0
  let idx = content.indexOf(needle)
  while (idx !== -1) {
    count += 1
    idx = content.indexOf(needle, idx + needle.length)
  }
  return count
}

function setsEqual(actual, expected) {
  const actualSet = new Set(actual)
  const expectedSet = new Set(expected)
  if (actualSet.size !== expectedSet.size) {
    return false
  }
  for (const item of expectedSet) {
    if (!actualSet.has(item)) {
      return false
    }
  }
  return true
}

function sliceExamplesOperationsSection(content) {
  const startIdx = content.indexOf('operations:\n')
  if (startIdx === -1) {
    return ''
  }
  return content.slice(startIdx + 'operations:\n'.length)
}

function extractExamplesOperationBlocks(opsSection) {
  const blocks = new Map()
  const lines = opsSection.split('\n')
  let currentId = null
  let currentLines = []

  for (const line of lines) {
    const match = line.match(/^  ([A-Za-z0-9]+):$/)
    if (match) {
      if (currentId) {
        blocks.set(currentId, currentLines.join('\n'))
      }
      currentId = match[1]
      currentLines = [line]
      continue
    }
    if (currentId) {
      currentLines.push(line)
    }
  }
  if (currentId) {
    blocks.set(currentId, currentLines.join('\n'))
  }
  return blocks
}

function extractExamplesRequestFieldKeys(opBlock) {
  const lines = opBlock.split('\n')
  const keys = []
  let inRequest = false

  for (const line of lines) {
    if (/^    request:\s*$/.test(line)) {
      inRequest = true
      continue
    }
    if (/^    request: null\s*$/.test(line)) {
      return []
    }
    if (inRequest && /^    (response|accepted|errors):/.test(line)) {
      break
    }
    if (inRequest) {
      const match = line.match(/^      ([A-Za-z0-9]+):/)
      if (match) {
        keys.push(match[1])
      }
    }
  }

  return keys
}

function extractExamplesErrorCodes(opBlock) {
  const codes = []
  const re = /^\s+-\s+code:\s+(?:"([^"]+)"|([A-Za-z0-9_]+))\s*$/
  for (const line of opBlock.split('\n')) {
    const match = line.match(re)
    if (match) {
      codes.push(match[1] ?? match[2])
    }
  }
  return codes
}

function validateExamples(openapi, allowlist) {
  const examples = readFile(EXAMPLES_PATH)
  if (!examples) {
    return
  }

  for (const needle of [
    'x-puls-public-http: false',
    'x-puls-current-transport: supabase-js',
    'operations:',
  ]) {
    if (!examples.includes(needle)) {
      fail(`examples file missing needle: ${needle}`)
    }
  }

  if (!openapi.includes('x-puls-examples-doc:')) {
    fail('openapi missing x-puls-examples-doc')
  }
  if (!openapi.includes('x-puls-error-catalog:')) {
    fail('openapi missing x-puls-error-catalog')
  }

  const examplesDocMatch = openapi.match(/^x-puls-examples-doc: (.+)$/m)
  if (examplesDocMatch) {
    const docPath = path.join(root, examplesDocMatch[1].trim())
    if (!fs.existsSync(docPath)) {
      fail(`x-puls-examples-doc file missing: ${examplesDocMatch[1].trim()}`)
    }
  }

  const catalogMatch = openapi.match(/^x-puls-error-catalog: (.+)$/m)
  if (catalogMatch) {
    const docPath = path.join(root, catalogMatch[1].trim())
    if (!fs.existsSync(docPath)) {
      fail(`x-puls-error-catalog file missing: ${catalogMatch[1].trim()}`)
    }
  }

  const knownCodes = new Set(allowlist.knownErrorCodes ?? [])
  if (knownCodes.size === 0) {
    fail('allowlist missing knownErrorCodes')
  }

  const opsSection = sliceExamplesOperationsSection(examples)
  if (!opsSection) {
    fail('examples missing operations section')
    return
  }

  const exampleBlocks = extractExamplesOperationBlocks(opsSection)
  const restoreIds = new Set(allowlist.restoreOperationIds ?? [])

  for (const opId of allowlist.operationIds) {
    const block = exampleBlocks.get(opId)
    if (!block) {
      fail(`examples missing operation block: ${opId}`)
      continue
    }

    if (restoreIds.has(opId)) {
      if (!/^    request: null\s*$/m.test(block)) {
        fail(`restore operation ${opId} must have request: null in examples`)
      }
    } else {
      if (!/^    request:/m.test(block)) {
        fail(`operation ${opId} missing request in examples`)
      }
      if (/^    request: null\s*$/m.test(block)) {
        fail(`non-restore operation ${opId} must not have request: null`)
      }
    }

    const hasResponse = /^    response:/m.test(block)
    const hasAccepted = /^    accepted:/m.test(block)
    if (!hasResponse && !hasAccepted) {
      fail(`operation ${opId} must have response or accepted in examples`)
    }
    if (hasAccepted && !block.includes('ok: true')) {
      fail(`operation ${opId} accepted block must include ok: true`)
    }

    if (!/^    errors:/m.test(block)) {
      fail(`operation ${opId} missing errors in examples`)
    }

    const errorCodes = extractExamplesErrorCodes(block)
    if (errorCodes.length === 0) {
      fail(`operation ${opId} must include at least one error code`)
    }
    for (const code of errorCodes) {
      if (!knownCodes.has(code)) {
        fail(`operation ${opId} error code not in knownErrorCodes: ${code}`)
      }
    }

    if (!restoreIds.has(opId)) {
      const opMeta = allowlist.operations?.[opId]
      const schemaName = opMeta?.requestSchema
      if (schemaName && allowlist.requestSchemaAllowlist?.[schemaName]) {
        const allowedFields = allowlist.requestSchemaAllowlist[schemaName]
        const requestKeys = extractExamplesRequestFieldKeys(block)
        for (const key of requestKeys) {
          if (!allowedFields.includes(key)) {
            fail(`operation ${opId} example request field not in allowlist: ${key}`)
          }
          if (allowlist.forbiddenRequestFields.includes(key)) {
            fail(`operation ${opId} example request contains forbidden field: ${key}`)
          }
        }
      }
    }
  }

  for (const [opId] of exampleBlocks) {
    if (!allowlist.operationIds.includes(opId)) {
      fail(`unexpected operation in examples: ${opId}`)
    }
  }
}

function validate() {
  const openapi = readFile(OPENAPI_PATH)
  const inventory = readFile(INVENTORY_PATH)
  const allowlistRaw = readFile(ALLOWLIST_PATH)

  if (!openapi || !inventory || !allowlistRaw) {
    return
  }

  let allowlist
  try {
    allowlist = JSON.parse(allowlistRaw)
  } catch (error) {
    fail(`invalid allowlist JSON: ${error.message}`)
    return
  }

  const pathsSection = sliceSection(openapi, 'paths:', ['components:'])
  const schemasSection = sliceSection(openapi, '  schemas:', ['x-puls-read-models:'])
  const operationBlocks = extractOperationBlocks(pathsSection)

  // --- Operation count and presence ---
  for (const opId of allowlist.operationIds) {
    if (!operationBlocks.has(opId)) {
      fail(`missing operation block: ${opId}`)
    }
  }

  for (const [opId] of operationBlocks) {
    if (!allowlist.operationIds.includes(opId)) {
      fail(`unexpected operation in OpenAPI: ${opId}`)
    }
  }

  if (operationBlocks.size !== allowlist.operationIds.length) {
    fail(`expected ${allowlist.operationIds.length} operations, found ${operationBlocks.size}`)
  }

  const operationMapIds = Object.keys(allowlist.operations ?? {})
  if (!setsEqual(operationMapIds, allowlist.operationIds)) {
    const expectedSet = new Set(allowlist.operationIds)
    const mapSet = new Set(operationMapIds)
    const missingFromMap = allowlist.operationIds.filter((id) => !mapSet.has(id))
    const extraInMap = operationMapIds.filter((id) => !expectedSet.has(id))
    const details = []
    if (missingFromMap.length > 0) {
      details.push(`missing from operations map: ${missingFromMap.join(', ')}`)
    }
    if (extraInMap.length > 0) {
      details.push(`extra in operations map: ${extraInMap.join(', ')}`)
    }
    fail(`allowlist operations map must match operationIds (${details.join('; ')})`)
  }

  // --- Per-operation contract map + vendor extensions ---
  for (const [opId, expected] of Object.entries(allowlist.operations)) {
    const block = operationBlocks.get(opId)
    if (!block) {
      continue
    }

    const requiredNeedles = [
      'x-puls-current-transport: supabase-js',
      'x-puls-public-http: false',
      'x-puls-boundary-class: app_exposed_mutation',
      'security:',
      'SupabaseJwt: []',
      'x-puls-auth:',
    ]
    for (const needle of requiredNeedles) {
      if (!block.includes(needle)) {
        fail(`operation ${opId} missing ${needle}`)
      }
    }

    const backend = extractLineValue(block, 'x-puls-backend')
    const transport = extractLineValue(block, 'x-puls-transport')
    const requestSchema = extractRequestSchemaRef(block)

    if (backend !== expected.backend) {
      fail(`operation ${opId} backend mismatch: expected ${expected.backend}, got ${backend ?? 'none'}`)
    }
    if (transport !== expected.transport) {
      fail(`operation ${opId} transport mismatch: expected ${expected.transport}, got ${transport ?? 'none'}`)
    }
    if (expected.requestSchema === null) {
      if (requestSchema !== null) {
        fail(`operation ${opId} must not have requestBody schema (expected null)`)
      }
      if (/requestBody:/.test(block)) {
        fail(`operation ${opId} must omit requestBody`)
      }
    } else if (requestSchema !== expected.requestSchema) {
      fail(
        `operation ${opId} requestSchema mismatch: expected ${expected.requestSchema}, got ${requestSchema ?? 'none'}`,
      )
    }
  }

  // --- Conditional vendor extensions ---
  for (const opId of allowlist.restoreOperationIds) {
    const block = operationBlocks.get(opId)
    if (block && /requestBody:/.test(block)) {
      fail(`restore operation ${opId} must omit requestBody`)
    }
  }

  for (const opId of allowlist.directTableWriteOperationIds) {
    const block = operationBlocks.get(opId)
    if (block && !block.includes('x-puls-tenant-guard:')) {
      fail(`direct table write ${opId} missing x-puls-tenant-guard`)
    }
  }

  for (const opId of allowlist.sourceOwnedOperationIds) {
    const block = operationBlocks.get(opId)
    if (block && !block.includes('x-puls-source-ownership:')) {
      fail(`source-owned operation ${opId} missing x-puls-source-ownership`)
    }
  }

  for (const opId of allowlist.partialCoverageOperationIds ?? []) {
    const block = operationBlocks.get(opId)
    if (!block) {
      continue
    }
    if (!block.includes('x-puls-coverage: partial')) {
      fail(`partial coverage operation ${opId} missing x-puls-coverage: partial`)
    }
    if (!block.includes('x-puls-follow-up:')) {
      fail(`partial coverage operation ${opId} missing x-puls-follow-up`)
    }
    if (opId === 'decideApprovalRequest') {
      const followUp = extractLineValue(block, 'x-puls-follow-up') ?? ''
      const residualNeedle =
        /success path|pending approver fixture|approver fixture/i.test(followUp)
      if (!residualNeedle) {
        fail(
          `decideApprovalRequest x-puls-follow-up must mention success path or pending approver fixture`,
        )
      }
    }
  }

  const contractSmokeIds = allowlist.contractSmokeOperationIds ?? []
  const partialIds = allowlist.partialCoverageOperationIds ?? []
  for (const opId of contractSmokeIds) {
    if (partialIds.includes(opId)) {
      fail(`operation ${opId} cannot be in both contractSmokeOperationIds and partialCoverageOperationIds`)
    }
    const block = operationBlocks.get(opId)
    if (!block) {
      continue
    }
    if (!block.includes('x-puls-coverage: contract_smoke')) {
      fail(`contract smoke operation ${opId} missing x-puls-coverage: contract_smoke`)
    }
    const coverageDoc = extractLineValue(block, 'x-puls-coverage-doc')
    if (!coverageDoc) {
      fail(`contract smoke operation ${opId} missing x-puls-coverage-doc`)
    } else {
      const docPath = path.join(root, coverageDoc)
      if (!fs.existsSync(docPath)) {
        fail(`contract smoke doc missing for ${opId}: ${coverageDoc}`)
      }
    }
    const expectedDoc = allowlist.contractSmokeDocs?.[opId]
    if (expectedDoc && coverageDoc !== expectedDoc) {
      fail(`contract smoke doc mismatch for ${opId}: expected ${expectedDoc}, got ${coverageDoc}`)
    }
  }

  for (const opId of partialIds) {
    if (contractSmokeIds.includes(opId)) {
      fail(`operation ${opId} cannot be in both contractSmokeOperationIds and partialCoverageOperationIds`)
    }
  }

  // --- Internal path guard ---
  for (const needle of allowlist.internalPathForbidden) {
    if (pathsSection.includes(needle)) {
      fail(`internal surface must not appear under paths: ${needle}`)
    }
  }

  // --- Top-level appendices ---
  for (const key of [
    'x-puls-read-models:',
    'x-puls-internal-backend-surfaces:',
    'x-puls-not-exposed:',
  ]) {
    if (!openapi.includes(`${key}\n`)) {
      fail(`missing top-level appendix: ${key}`)
    }
  }

  const appendixRoutes = extractAppendixRoutes(openapi)
  for (const route of allowlist.readModelRoutes) {
    if (!appendixRoutes.includes(route)) {
      fail(`x-puls-read-models missing route: ${route}`)
    }
  }
  if (appendixRoutes.length !== allowlist.readModelRoutes.length) {
    fail(
      `x-puls-read-models route count mismatch: expected ${allowlist.readModelRoutes.length}, found ${appendixRoutes.length}`,
    )
  }

  const menuSection = sliceSection(openapi, 'x-puls-read-models:', ['x-puls-internal-backend-surfaces:'])
  if (!menuSection.includes('route: /menu') || !menuSection.includes('shellException: true')) {
    fail('/menu read model must include shellException: true')
  }

  // --- Request schema allowlist (exact property sets) ---
  for (const [schemaName, allowedFields] of Object.entries(allowlist.requestSchemaAllowlist)) {
    const properties = extractSchemaProperties(schemasSection, schemaName)
    if (properties.length === 0) {
      fail(`missing or empty schema properties: ${schemaName}`)
      continue
    }
    if (!setsEqual(properties, allowedFields)) {
      fail(
        `schema ${schemaName} property mismatch: expected [${allowedFields.join(', ')}], got [${properties.join(', ')}]`,
      )
    }
  }

  const requestBlocks = extractRequestSchemaBlocks(schemasSection)
  for (const { name, text } of requestBlocks) {
    for (const field of allowlist.forbiddenRequestFields) {
      if (text.includes(field)) {
        fail(`forbidden field ${field} in ${name}`)
      }
    }
  }

  // --- Adapter drift: exactly once in inventory + OpenAPI ---
  for (const adapter of allowlist.mutationAdapters) {
    const inventoryCount = countExactNeedle(inventory, adapter) || countSubstring(inventory, `\`${adapter}\``)
    if (inventoryCount < 1) {
      fail(`adapter ${adapter} missing from inventory`)
    }
    const openapiCount = countExactNeedle(openapi, adapter)
    if (openapiCount !== 1) {
      fail(`adapter ${adapter} must appear exactly once as operationId in OpenAPI (found ${openapiCount})`)
    }
  }

  // --- Backend drift: inventory + at least once in OpenAPI ---
  for (const backend of allowlist.backendObjects) {
    if (!inventory.includes(backend)) {
      fail(`backend ${backend} missing from inventory`)
    }
    const openapiCount = countSubstring(openapi, backend)
    if (openapiCount < 1) {
      fail(`backend ${backend} must appear at least once in OpenAPI`)
    }
  }

  validateExamples(openapi, allowlist)
}

validate()

if (failures.length > 0) {
  for (const message of failures) {
    console.error(`FAIL: ${message}`)
  }
  process.exit(1)
}

console.log('OK: OpenAPI contract validation passed')
