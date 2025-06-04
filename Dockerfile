ARG RUBY_VERSION=3.4.4

FROM ruby:$RUBY_VERSION-alpine AS base

WORKDIR /stoplight

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

FROM base AS build

RUN apk --update --no-cache add build-base

COPY Gemfile Gemfile.lock stoplight.gemspec ./
COPY lib/stoplight/version.rb ./lib/stoplight/version.rb

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git
COPY . .

FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /stoplight /stoplight

# Run and own only the runtime files as a non-root user for security
RUN addgroup --g 1000 -S stoplight && \
    adduser -u 1000 -D -S -G stoplight stoplight

USER 1000:1000

EXPOSE 4567

CMD ["bundle", "exec", "puma", "-p", "4567"]

