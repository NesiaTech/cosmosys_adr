# syntax=docker/dockerfile:1.7@sha256:a57df69d0ea827fb7266491f2813635de6f17269be881f696fbfdf2d83dda33e

# The image the CI tests run in: the deployment image (the cosmosys context of
# docker-bake.hcl) plus Redmine's test gem group, which the official Redmine
# image leaves out, and a test database on the host db.
FROM cosmosys

RUN apt-get -o Acquire::Retries=5 update \
    && apt-get -o Acquire::Retries=5 install -y --no-install-recommends build-essential pkg-config libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

COPY <<'YAML' config/database.yml
test:
  adapter: postgresql
  host: db
  database: redmine_test
  username: <%= ENV.fetch('POSTGRES_USER', 'redmine') %>
  password: <%= ENV.fetch('POSTGRES_PASSWORD') %>
  encoding: utf8
YAML

RUN bundle config set --local without development \
    && bundle install \
    && rm -rf /root/.bundle/cache /usr/local/bundle/cache

# The test database is migrated as an instance is, with Redmine's and the
# plugins' migrations, never loaded from a db/schema.rb.
RUN printf '\nconfig.active_record.maintain_test_schema = false\n' >>config/additional_environment.rb
