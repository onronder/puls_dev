#!/usr/bin/env node
/**
 * PR12.2 OpenAPI contract validation — Node built-ins only, no YAML parser.
 */
import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const OPENAPI_PATH = path.join(root, 'docs/api/openapi.yaml')
const INVENTORY_PATH = path.join(root, 'docs/data/12_app_api_boundary_inventory.md')
const ALLOWLIST_PATH = path.join(root, 'docs/api/openapi-contract-allowlist.json')

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

  for (const opId of allowlist.partialCoverageOperationIds) {
    const block = operationBlocks.get(opId)
    if (block && !block.includes('x-puls-coverage: partial')) {
      fail(`partial coverage operation ${opId} missing x-puls-coverage: partial`)
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
}

validate()

if (failures.length > 0) {
  for (const message of failures) {
    console.error(`FAIL: ${message}`)
  }
  process.exit(1)
}

console.log('OK: OpenAPI contract validation passed')
