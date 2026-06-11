#!/usr/bin/env node
import { readFile } from 'node:fs/promises'
import { resolve } from 'node:path'

import { extractReceiptFieldsFromText } from '../services/workflow-evidence-worker/src/local-extraction.ts'

const fixturePath = resolve(
  process.argv[2] ?? 'docs/data/17_2_g4c_expense_receipt_ocr_benchmark_fixtures.json',
)

function valuesEqual(actual, expected) {
  if (typeof expected === 'number') {
    return typeof actual === 'number' && Math.abs(actual - expected) < 0.001
  }
  return actual === expected
}

function scoreFixture(fixture) {
  const extraction = extractReceiptFieldsFromText(fixture.input_text ?? '')
  const expected = fixture.expected ?? {}
  const expectedEntries = Object.entries(expected)
  const correctFields = expectedEntries.filter(([field, expectedValue]) =>
    valuesEqual(extraction.fields[field], expectedValue),
  )
  const adversarialInstructionIgnored =
    fixture.adversarial === true && extraction.fields.total_amount === expected.total_amount

  return {
    id: fixture.id,
    route_used: extraction.routeUsed,
    expected_route: fixture.route_hint,
    field_count: expectedEntries.length,
    correct_field_count: correctFields.length,
    field_accuracy:
      expectedEntries.length === 0
        ? 1
        : Number((correctFields.length / expectedEntries.length).toFixed(4)),
    adversarial_instruction_ignored:
      fixture.adversarial === true ? adversarialInstructionIgnored : null,
    warnings: extraction.warnings,
  }
}

const fixtures = JSON.parse(await readFile(fixturePath, 'utf8'))
if (!Array.isArray(fixtures)) {
  throw new Error('G4C benchmark fixture file must contain an array.')
}

const results = fixtures.map(scoreFixture)
const scoredResults = results.filter((result) => result.field_count > 0)
const summary = {
  benchmark: 'pr17.2g4c-local-extraction',
  fixture_count: fixtures.length,
  route_coverage: Object.fromEntries(
    [...new Set(results.map((result) => result.route_used))].map((route) => [
      route,
      results.filter((result) => result.route_used === route).length,
    ]),
  ),
  mean_field_accuracy:
    scoredResults.length === 0
      ? 0
      : Number(
          (
            scoredResults.reduce((sum, result) => sum + result.field_accuracy, 0) /
            scoredResults.length
          ).toFixed(4),
        ),
  adversarial_instruction_ignored_count: results.filter(
    (result) => result.adversarial_instruction_ignored === true,
  ).length,
  external_call: false,
  results,
}

console.log(JSON.stringify(summary, null, 2))
