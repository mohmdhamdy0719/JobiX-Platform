# Jobix

**The canonical project handoff is [PROJECT_HANDOFF.md](PROJECT_HANDOFF.md).**

Jobix is a native Flutter mobile app backed by Supabase. The current app implements
English/Arabic onboarding, account authentication, a six-step Career Profile
builder, profile editing, local encrypted drafts, and the first Resume
configuration/HTML preview foundations. Provider-backed AI and PDF export are
not yet enabled.

Start with the root handoff, then read [mobile/jobix/README.md](mobile/jobix/README.md)
for Flutter setup and [docs/handoff/](docs/handoff/) for the architecture,
decisions, history, verification, known gaps, and account migration.
Architecture V2, the Constitution, and Product Design are preserved in
`attached_assets/`; see [the handoff's authority map](docs/handoff/02_ARCHITECTURE.md).

The pnpm workspace at the repository root is Replit starter infrastructure,
not a second Jobix client. See the migration guide before setting up integrations
or infrastructure. Never commit local configuration or credentials.
