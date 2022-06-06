# GraphitiGql

GraphQL bindings for [Graphiti](www.graphiti.dev).

Write code like this:

```ruby
class EmployeeResource < ApplicationResource
  attribute :first_name, :string
  attribute :age, :integer
  
  has_many :positions
end
```

Get an API like this:

```gql
query {
  employees(
    filter: { firstName: { match: "arha" } },
    sort: [{ att: age, dir: desc }],
    first: 10,
    after: "abc123"
  ) {
    edges {
      node {
        id
        firstName
        age
        positions {
          nodes {
            title
          }
        }
      }
      cursor
    }
    stats {
      total {
        count
      }
    }
  }
}
```

### Getting Started

```ruby
# Gemfile
gem 'graphiti'
gem "graphiti-rails"
gem 'graphiti_gql'
```

```ruby
# config/routes.rb

Rails.application.routes.draw do
  scope path: ApplicationResource.endpoint_namespace do
    mount GraphitiGql::Engine, at: "/gql"
  end
end
```

Write your Graphiti code as normal, omit controllers.

### How does it work?

This autogenerates `graphql-ruby` code by introspecting Graphiti Resources. Something like this happens under-the-hood:

```ruby
field :employees, [EmployeeType], null: false do
  argument :filter, EmployeeFilter, required: false
  # ... etc ...
end

def employees(**arguments)
  EmployeeResource.all(**arguments).to_a
end
```

In practice it's more complicated, but this is the basic premise - use Graphiti resources to handle query and persistence operations; autogenerate `graphql-ruby` code to expose those Resources as an API. This means we play nicely with e.g. telemetry and error-handling libraries because it's all `graphql-ruby` under-the-hood...except for actually **performing** the operations, which is really more a Ruby thing than a GraphQL thing.

### Caveats

This rethinks the responsibilities of Graphiti, coupling the execution cycle to `graphql-ruby`. We do this so we can play nicely with other gems in the GQL ecosystem, and saves on development time by offloading responsibilities. The downside is we can no longer run a `JSON:API` with the same codebase, and certain documentation may be out of date.

Longer-term, we should rip out only the parts of Graphiti we really need and redocument.
