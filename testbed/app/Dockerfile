FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    BUNDLE_WITHOUT=development:test \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ca-certificates libsqlite3-dev pkg-config ruby-dev ruby-full tzdata \
    && gem install bundler --no-document \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY Gemfile Gemfile.lock rails_saas_guard.gemspec /workspace/
COPY lib /workspace/lib
COPY testbed/app/Gemfile /workspace/testbed/app/Gemfile
WORKDIR /workspace/testbed/app
RUN bundle install
WORKDIR /workspace
COPY . /workspace
WORKDIR /workspace/testbed/app

EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
