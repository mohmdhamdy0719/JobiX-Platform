# Managed DEVELOPMENT Cloud Build only; never build/run Docker in this workspace.
FROM dart:3.8.0-sdk AS canonical
WORKDIR /source
COPY lib/features/career_profile/ lib/features/career_profile/
COPY lib/features/resume/resume_render.dart lib/features/resume/resume_document.dart lib/features/resume/
COPY tool/prepare_resume_document.dart tool/
RUN dart compile exe tool/prepare_resume_document.dart -o /canonical

FROM node:24.21.0-bookworm
ENV NODE_ENV=production PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
    JOBIX_CANONICAL_EXECUTABLE=/opt/jobix/canonical \
    JOBIX_DEV_DATABASE_CA_FILE=/opt/jobix/assets/certs/supabase-root-2021.crt
WORKDIR /opt/jobix/backend/pdf
RUN corepack enable && corepack prepare pnpm@10.26.1 --activate
COPY backend/pdf/package.json backend/pdf/pnpm-lock.yaml ./
RUN pnpm install --ignore-workspace --frozen-lockfile --prod && \
    pnpm exec playwright install --with-deps chromium --only-shell && \
    apt-get update && apt-get install -y --no-install-recommends poppler-utils && \
    rm -rf /var/lib/apt/lists/*
COPY --from=canonical /canonical /opt/jobix/canonical
COPY assets/fonts/ /opt/jobix/assets/fonts/
COPY assets/certs/supabase-root-2021.crt /opt/jobix/assets/certs/
COPY backend/pdf/*.mjs ./
RUN useradd --create-home --uid 10001 exportworker && \
    chown -R exportworker:exportworker /opt/jobix && chmod -R a+rX /ms-playwright
USER exportworker
EXPOSE 8080
CMD ["node","server.mjs"]
