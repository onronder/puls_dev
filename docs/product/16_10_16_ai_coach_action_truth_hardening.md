# PR16.10.16 AI Coach Action Truth Hardening

## Goal

Close the remaining pre-PR17 product-truth gap on `/ai-koc`: the page must not claim that a user was added to an AI Coach notification list unless a durable backend notification or subscription record is actually created.

## Scope

- Remove the non-durable "Notify me" action from the AI Coach teaser page.
- Remove unused AI Coach notify sheet/toast locale strings that promised a successful signup.
- Keep the page read-only and honest until the PR17 AI layer adds a real notification/subscription contract.
- Add a verify gate that prevents the fake notify action from returning.

## Safety Boundary

This PR does not change:

- Supabase schema or migrations;
- Notification Center ledger, preferences, realtime, or delivery behavior;
- AI runtime, LLM gateway, or autonomous actions;
- AI Coach context-readiness data loading;
- other HR pages.

## Acceptance

- `/ai-koc` no longer imports `toast` or `Bell` for a fake notification signup.
- `/ai-koc` does not call `toast.info` for notification signup.
- AI Coach notify signup/toast i18n keys are removed from both locale files.
- The only visible CTA on the teaser page is the real dashboard navigation action.
- Typecheck, tests, i18n, build, and the PR16.10.16 verify gate pass.
