# PR14.12B Connector State Consistency Findings

PR14.12B closes the production findings discovered after the source credential boundary reached the remote Supabase project.

PULS is source-independent. Canias is one source profile; the connector backbone must work for ERP, file, and future custom API sources without becoming Canias-specific.

## What This PR Fixes

| Finding | Product risk | PR14.12B decision |
|---------|--------------|-------------------|
| Dashboard said `Kontrol temiz` while `/erp` showed credential warning | Users would trust a setup that is not ready for live connection | Dashboard ERP card now treats missing credentials as `Credential pending`, not clean |
| Multiple rows could represent the same provider/domain setup | Duplicate source ownership can make mapping and future imports inconsistent | Adapter selects the strongest current connector and setup start resumes existing domain ownership |
| Running setup check did not leave durable history | Admin actions were not auditable and `Kontrol geçmişi` stayed empty | Setup preflight writes a metadata-only `setup_preflight` history row |

## State Truth Rules

- `preflight_ready` means all dry-run setup checks are clean.
- A source that requires credentials but has no secure reference cannot be called clean.
- Missing or configured-but-unverified credentials are warning/partial posture until a future server-side verifier marks them verified.
- A tenant may have multiple data sources only when they own different canonical domains or an explicit ownership transfer is designed.
- Starting setup for an already owned provider/domain must resume the existing setup instead of creating a duplicate.

## Runtime Boundary

PR14.12B does not enable connector runtime, live API calls, imports, exports, credential capture, credential readback, or ERP writes.

The setup check writes only safe metadata: check status, passed/warning/blocked counts, and a timestamp. It does not move customer data.

## Handoff

PR14.13 should formalize source capability and lifecycle modeling:

- source profile vs connection instance
- domain ownership and transfer
- capability availability by connector type
- credential verification boundary
- post-connection states and activity timeline
