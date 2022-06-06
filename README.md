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

### How does it work?
