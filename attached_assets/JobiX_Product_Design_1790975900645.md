# JobiX — Product Design

**Version:** Official First Release  
**Status:** Ready  
**Document Type:** Product Design & UX Source of Truth  
**Scope:** MVP

---

## 1. Product Overview

JobiX is a career-focused application that helps users build, manage, and use professional information and career documents.

The core first-release journey is:

> **Write information your way → JobiX helps make it professional → assess CV quality → choose language and template → Preview → Export PDF**

JobiX is not only a Resume Builder. The Career Profile is the foundation for future tools such as Cover Letter, Professional Email, job-specific CV optimization, interview preparation, and broader career assistance.

## 2. Product Principles

### Core Promise
> **Write it your way. JobiX will help make it professional.**

### User Truth
AI must never invent, assume, or exaggerate achievements, metrics, responsibilities, tools, employers, titles, dates, qualifications, certifications, skills, or experience. It may improve language, clarity, professional tone, organization, conciseness, and repetition, but the user remains the source of truth.

### User Control
Every AI output is a proposal. Nothing is applied automatically, and original content remains viewable and recoverable.

### Don't Block Users Unnecessarily
Poor writing or a low ATS Readiness Score must not prevent Export. Export is blocked only when core information is missing or invalid enough to prevent a usable CV.

### Low Cognitive Load
The Profile uses a Guided Flow with free navigation, allowing users to complete it progressively.

---

## 3. Core Concepts

### User
The account that owns Career Profiles, Credits, AI allowances, Daily Reward, Application-level Personal Data, Settings, and History.

### Application-level Personal Data
Reusable personal information primarily used for creating new Profiles, Cover Letter, Professional Email, and future tools. Editing it does not automatically change existing Profiles.

### Career Profile
An independent professional version containing Personal Information, Target Role, Summary, Work Experience, Education, Projects, Skills, Languages, and optional sections.

### Resume
A presentation/output of a Career Profile. Resume language and template are output choices and do not require a new Profile.

---

## 4. Onboarding

### Screen 1 — Build a Stronger CV
**Title:** Build a professional, ATS-friendly CV

**Description:** Create a CV that clearly presents your experience, skills, and strengths — without the hassle of starting from scratch.

### Screen 2 — Improve Your Content with AI
**Title:** Turn your experience into professional content

**Description:** Describe your experience in your own words. JobiX can help refine it into clear, professional CV-ready content — without inventing information.

### Screen 3 — Create & Keep Your CV Ready
**Title:** Create it once. Update it anytime.

**Description:** Choose your CV template, export it as a PDF, and keep your information ready to update whenever your career changes.

A small language switch may appear during onboarding; no separate language-selection screen is required.

---

## 5. Initial Questions

### Q1
**Which best describes your current career stage?**
- Student
- Recent Graduate (0–1 year of experience)
- Early-Career Professional (1–3 years of experience)
- Mid-Career Professional (4–7 years of experience)
- Experienced Professional (8+ years of experience)
- Return to work after a break
- Career Changer

### Q2
**What are you currently looking to achieve in your career?**
- Find my first job
- Find a new or better job
- Change my career
- Advance in my current career
- Prepare for future opportunities
- I'm not sure yet

### Q3
**Where are you currently looking for job opportunities?**
- In my current city
- Elsewhere in my country
- Remotely
- Abroad
- Open to multiple options
- I'm not sure yet

### Q4
**What would you most like help with in your career?**
Select up to 3:
- Create a stronger CV
- Find better career opportunities
- Discover suitable career paths
- Work Online
- Learn New Skills
- Prepare for job interviews

These questions may inform personalization but must not prevent use of the app.

---

## 6. Authentication and First Profile

After the questions:
1. Authentication
2. Career Profile is automatically created
3. User is taken directly to Personal Information

The Career Profile is created after registration and starts empty.

Users are not forced to complete it before exploring the app.

---

## 7. Saving During Building

Unsynced edits are stored locally. At an appropriate Next/Save point they are synchronized.

If the user chooses **Discard**, unsynced local data is deleted and cannot be recovered.

If connectivity is lost or the app closes, the user can continue from local data.

---

## 8. Career Profile Builder

**Guided Flow + Free Navigation**

Core order:
1. Personal Information
2. Target Role
3. Summary
4. Work Experience
5. Education
6. Projects
7. Skills
8. Languages

Optional sections may include Volunteer Experience, Certifications, Awards, and Publications.

### Section States
- Not Added
- In Progress
- Complete
- Needs Attention

If an optional section is no longer wanted, the user can remove/disable it so it does not appear in the CV.

---

## 9. Personal Information

### Required for Export
**Full Name** — `e.g. Mohamed Hamdy Hassan`  
**Phone** — `e.g. +20 100 123 4567`  
**Email** — `e.g. mohamed.hassan@email.com`

### Optional
**Country** — `e.g. Egypt`  
**City** — `e.g. Alexandria`  
**LinkedIn** — `e.g. linkedin.com/in/mohamedhassan`  
**GitHub** — `e.g. github.com/mohamedhassan`  
**Portfolio** — `e.g. mohamedhassan.dev`

Country is suggested automatically from device/region when reasonably available and can be changed. City uses autocomplete with support for custom values.

Country and City do not block Export.

---

## 10. Validation

### Email
The format must be valid. Example: `mohamed@gmail.com`.

### Phone
Validate country, allowed characters, plausible length, and appropriate format for the selected country. Passing format validation does not mean the number has been verified as active.

Validation should be non-intrusive, such as on blur or when moving forward/saving.

---

## 11. Target Role

Optional.

Example:
> `e.g. Senior Frontend Developer`

It helps with positioning and AI context and can slightly improve ATS Readiness, but it does not block Export.

---

## 12. Summary

Primary placeholder:
> **Tell us about your experience, strengths, and career direction.**

Hints:
- What is your professional background?
- What are your strongest skills?
- What type of work do you specialize in?
- What are you currently looking for?
- What makes you valuable in your field?

Each hint expands to show a practical example.

**Length:** 50–1,000 characters. Below the minimum = Needs Attention. Maximum = Hard Limit.

---

## 13. Work Experience

Fields:
- Job Title
- Company
- Location
- Start Date
- End Date / Present
- Description

Examples:
- Job Title: `e.g. Software Engineer`
- Company: `e.g. Tech Solutions`

Description placeholder:
> **Write it your way. JobiX will help make it professional.**

Hints:
- What were your main responsibilities?
- What did your typical day involve?
- What tools, software, or systems did you use?
- Who did you work with or support?
- What problems did you solve?
- What did you improve or accomplish?
- Can you mention any measurable results?

Each hint expands to show an example.

**Description:** minimum 20 characters, maximum 1,500. Below minimum = Needs Attention. Maximum = Hard Limit.

---

## 14. Education

Fields:
- Degree
- Institution
- Field of Study
- Start Date
- End Date / Present
- Description/Achievements — optional

Examples:
- `e.g. B.Sc. Computer Science`
- `e.g. Alexandria University`
- `e.g. Computer Science`

Hints help users think about relevant coursework, thesis, academic projects, achievements, and awards.

---

## 15. Projects

Fields:
- Project Name
- Role
- Description
- Date
- URL — optional

Project Name:
> `e.g. E-commerce Mobile App`

Description:
> **Describe what you built, your role, and what you achieved.**

Hints:
- What did you build?
- What problem did it solve?
- What was your role?
- What tools/technologies did you use?
- What did you accomplish?
- What was the result?

---

## 16. Skills

> **Search or type a skill**

Placeholder:
> `e.g. Python, SQL, Excel, Power BI`

Skills appear as chips. Users can Add/Remove/Reorder.

Reference data may power autocomplete, but the list is not closed and custom skills are allowed.

---

## 17. Languages

Each entry contains:
- Language
- Proficiency

Example:
> Arabic — Native  
> English — Professional

Users can Add/Edit/Delete/Reorder.

---

## 18. Hints System

Every important writing section has Hints.

A Hint:
- is not an input
- is not required
- is not independent user data
- helps users recall real information
- reveals an example when expanded

Hints help users provide better facts to AI; they do not give AI facts the user did not provide.

---

## 19. Profile Completeness

Profile Completeness measures how complete the professional information is, not how well it is written.

Example:
> **Profile Completeness — 72%**

It can coexist with any ATS Readiness value.

### First AI transition
When Profile Completeness reaches **50% or higher**, the First Profile Building allowance ends and the daily allowance begins from the next day.

---

## 20. JobiX ATS Readiness Score

**0–100**

It assesses how well the CV follows JobiX's evaluation of:
- ATS-friendly structure
- content quality
- clarity
- consistency
- relevance
- readable formatting

It is not:
- a universal ATS score
- a hiring probability
- an interview guarantee
- a job-match score

### Scoring Framework

| Dimension | Weight |
|---|---:|
| Structure & ATS Compatibility | 20% |
| Experience / Evidence Quality | 25% |
| Content Clarity & Professional Language | 15% |
| Skills Quality & Relevance | 15% |
| Summary & Career Positioning | 10% |
| Consistency & Data Quality | 10% |
| Contact / Basic Professional Information | 5% |
| **Total** | **100%** |

### HR Rules
The Score must not punish Students, Fresh Graduates, or Career Changers simply for having fewer years of experience. It evaluates the quality of evidence appropriate to the candidate context: Education, Projects, Skills, and other relevant evidence can be meaningful for early-career users.

Target Role has a small impact.

### Evaluation
Use deterministic checks where possible and AI evaluation where language understanding is required. AI must not run on every keystroke.

---

## 21. ATS Recommendations

Examples:

**Summary — Needs improvement**  
Your summary is too generic and does not clearly communicate your professional direction.

**Experience — Needs improvement**  
Several descriptions focus on responsibilities without clearly communicating impact.

**Skills**  
Consider adding skills that are clearly supported by your experience.

**Consistency**  
Some dates or formatting patterns are inconsistent.

---

## 22. Export Rules

**ATS Readiness does not block Export.**

A user may Export with a low Score if core CV information is valid.

### Export blockers
- Full Name present
- Phone present and valid in format
- Email present and valid in format
- Minimum meaningful Career Content exists
- Any section intended to appear in the CV is Complete
- No invalid information prevents production of a usable CV

Target Role, Country, and City are not blockers.

Summary is not a blocker if the user does not use it.

Work Experience is not a blocker when it is inappropriate, such as for a student, provided suitable Career Content exists such as Education/Projects/Skills.

If an added section is incomplete:
> Needs Attention

The user can complete it or remove/disable it so it does not appear.

---

## 23. Resume Language & Template

CV language is independent from app language:
- English
- العربية

It can be changed later.

One Career Profile can produce either an English or Arabic CV.

The MVP contains:
- English professional ATS-friendly template
- Arabic professional ATS-friendly template

---

## 24. Preview and PDF Export

Preview must represent the same content/order/language/template/visibility that will appear in the PDF.

### Export
Each new Export = **2 Credits**.

Downloading an existing valid PDF = **0 Credits**.

A failed Export must not permanently consume Credits.

---

## 25. AI Writing

### Free
**Analyze My CV**
- weaknesses
- areas needing improvement
- general recommendations
- factors affecting ATS Readiness

### Premium
**Optimize My CV**
- Current → Proposed
- specific improvements
- Apply / Reject
- skill additions
- suggested removals/replacements only after explicit user approval

No modification is applied automatically.

---

## 26. AI Generation System

### First Career Profile
**6 total AI generations**, shared across the entire first Profile-building process.

Not 6 per Section, Page, Field, or Profile.

Each press:
> **Improve with JobiX**

= **one generation**

The user can edit the source text and regenerate.

The user can switch between Original and each generated version and choose any version.

### After First Profile Building
When Profile Completeness reaches ≥50%, the six-generation first-profile grant ends. Unused generations are not converted into a new allowance.

Starting the next day:
> **3 generations / user / day**

Premium:
> **10 generations / user / day**

Daily allowance is shared across all Profiles.

---

## 27. AI Generation History

Each generation conceptually records:
- Profile
- Section/Field
- Source User Input
- AI Output
- Generation metadata

Example:
> Generation 1: Source → AI Output  
> Generation 2: Source → AI Output

When copying a Profile, copy **current accepted content only**. Do not copy AI history, rejected generations, unused proposals, or generation allowance.

---

## 28. AI Anti-Abuse and Version Policy

The user must not receive a new first-profile grant simply by logging out, creating another account, creating another Profile, or deleting a Profile.

The first-profile grant and daily allowance are server-authoritative.

The app must not treat a local counter as the source of truth.

If an old app version is incompatible with current policy, the server can return:
> **APP_UPDATE_REQUIRED**

The values 6, 3/day, and 10/day must be configurable server-side so Free can later be reduced, for example from 3/day to 1/day, without redesigning the product.

---

## 29. AI Failure

Offline:
> Improve with JobiX is unavailable while you're offline.

Failure:
> We couldn't improve this content right now. Your original text is safe. Try again.

A failure must not change active content or unfairly consume a generation.

---

## 30. Career Profiles

### Slots
- Profile 1: Free
- Profile 2: 10 Credits once
- Profile 3: 20 Credits once

A purchased slot remains unlocked permanently. If Profile 2 is deleted after purchase, Slot 2 remains unlocked and can be reused without paying again.

---

## 31. Copy Profile

> Create New Profile → Copy Existing Profile

Copy current accepted content only.

Do not copy:
- AI history
- rejected generations
- unused proposals
- generation allowance

The new Profile is independent.

---

## 32. Credits

| Operation | Credits |
|---|---:|
| Initial Signup | +5 |
| PDF Export | −2 |
| Professional Email | −1 |
| Cover Letter — New PDF Export | −1 |
| Daily Reward | +2 |
| Profile 1 | Free |
| Profile 2 | −10 once |
| Profile 3 | −20 once |

---

## 33. Daily Reward

Reward:
> **+2 Credits**

At the user's first App Open each day using Africa/Cairo:
- Finalized balance < 9 → Eligible
- Finalized balance ≥ 9 → Not eligible

Eligibility is frozen for that day.

After a verified Rewarded Ad:
> +2 Credits

---

## 34. Home

Home is the Career Command Center and shows:
- Current Career Profile
- ATS Readiness
- Profile Completeness
- most useful Next Actions
- Credits
- Daily Reward when available
- Recent Exports

If the Profile is incomplete:
> **Your Career Profile isn't complete yet.**  
> Complete your profile to create your CV.

CTA:
> **Continue Profile**

The user is not forced to complete it immediately.

---

## 35. Career

Bottom Navigation:
> **Home | Career | Settings**

Career opens the last-used Profile.

Top controls:
- Switch Profile
- Rename
- Delete
- Add New Profile

---

## 36. Settings

### Account
- Account information
- Sign out
- Delete Account

### App
- App Language

### Personal Data
- Application-level Personal Data

### History
- Export History

### Legal
- Privacy Policy
- Terms of Service

---

## 37. Account Deletion

When selecting Delete Account:

> **Delete your JobiX account?**

> This will permanently delete your account and all associated data. This action cannot be undone.

Explicit confirmation is required. The product goal is to delete all user data associated with the account according to the deletion policy.

---

## 38. App Language

First launch:
> App language = Device language

A small switch is available during onboarding.

Later:
> Settings → App Language

Languages:
- العربية
- English

Arabic app UI = RTL.  
English app UI = LTR.

CV direction is independent from UI direction.

---

## 39. Location Data

Store reference data for all countries and Egyptian governorates for the current Egypt-focused market.

City uses autocomplete with custom values allowed.

When additional countries are targeted, their relevant administrative data can be added.

---

## 40. History

Export History stores metadata.

Generated PDF files are retained for:
> **7 days**

After that:
> Expired

The History record remains and offers:
> Export Again

Downloading a valid existing PDF consumes no Credits.

---

## 41. Student / Fresh Graduate

JobiX must not assume every user has Work Experience.

A strong CV can use:
- Education
- Projects
- Skills
- Summary
- relevant activities

ATS Readiness must not punish someone simply for lacking years of experience.

---

## 42. Core User Journeys

### New User
Open → Onboarding → 4 Questions → Authentication → Career Profile auto-created → Personal Information → Builder → AI assistance → Profile Completeness → Resume Language/Template → Preview → Export.

### Returning User
Open → Home → Current Profile → ATS Readiness → Next Action → Career → Edit.

### Improve Content
Write naturally → Hints → Improve with JobiX → Generation 1 → Edit source → Generation 2 → Choose preferred version.

---

## 43. Product Metrics

Track:
- Activation rate
- First Profile creation
- Profile Completeness ≥50%
- First Export
- Export conversion
- AI adoption
- Average generations/user
- Free → Premium conversion
- Daily Reward usage
- Profile 2/3 purchases
- Export failure rate
- Time to first CV

---

## 44. MVP Included

### Career
Profiles, 3 slots, Personal Information, Target Role, Summary, Experience, Education, Projects, Skills, Languages, Hints, Validation, Profile Completeness, ATS Readiness.

### Resume
Arabic, English, templates, Preview, PDF Export, History.

### AI
Free CV Analysis, Improve with JobiX, first-profile 6 generations, Free 3/day, Premium 10/day, Premium Optimize My CV, generation history, Original/AI switching.

### Credits
Signup Credits, Export Credits, Profile Slot Credits, Daily Reward, Professional Email, Cover Letter.

### Application
Arabic/English, Home, Career, Settings, Privacy, Terms, Account Deletion, Sign out.

---

## 45. Out of Scope for Initial MVP

- Job board integrations
- Automatic job applications
- Full job matching
- LinkedIn automation
- Community/social feed
- Creator profiles
- Service marketplace
- Unlimited Profiles
- Unlimited AI
- AI on every keystroke
- Automatic AI modifications
- Fabricated achievements
- Multiple simultaneous Resume versions
- Multiple tailored CV variants per Profile

---

## 46. Final Product Rules

| Rule | Final Decision |
|---|---|
| Profile 1 | Free |
| Profile 2 | 10 Credits once |
| Profile 3 | 20 Credits once |
| Export | 2 Credits |
| Existing PDF download | Free |
| Signup | +5 Credits |
| Daily Reward | +2 Credits |
| ATS Readiness | 0–100 |
| ATS blocks Export | No |
| Missing core information blocks Export | Yes |
| Target Role | Optional |
| Country | Optional |
| City | Optional |
| Profile Completeness | Separate metric |
| First AI grant | 6 generations |
| First grant scope | Entire first Profile building |
| One press | One generation |
| Free daily after building | 3/day/user |
| Premium | 10/day/user |
| Daily scope | All Profiles combined |
| AI original | Always recoverable |
| Copy Profile | Current accepted content only |
| AI history copied | No |
| App languages | Arabic + English |
| CV languages | Arabic + English |
| Device language default | Yes |
| PDF retention | 7 days |
| AI fabrication | Never |

---

## 47. Definition of Done

The Product Design is Ready when:
1. All core journeys are defined.
2. All Export blockers are defined.
3. Profile Completeness is separate from ATS Readiness.
4. AI behavior and allowances are defined.
5. Career Profile and Resume are separate product concepts.
6. Language and RTL/LTR behavior are defined.
7. Credits are defined.
8. Empty/Error/Attention states are defined.
9. Account deletion, Privacy, Terms, and Settings are defined.
10. The decisions above are the Source of Truth for Architecture, UI/UX, and implementation.

**Status: READY**
