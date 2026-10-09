# Managed development build only; no downloaded service-account credentials.
FROM node:20.20.0-bookworm-slim
WORKDIR /opt/jobix
ENV NODE_ENV=production JOBIX_EXPORT_ENABLED=false
COPY backend/export-gateway/*.mjs backend/export-gateway/
COPY supabase/functions/resume-export/transport.mjs supabase/functions/resume-export/
USER node
EXPOSE 8080
CMD ["node","backend/export-gateway/server.mjs"]
