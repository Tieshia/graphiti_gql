require "spec_helper"

RSpec.describe GraphitiGql do
  describe "basic" do
    let(:resource) do
      Class.new(PORO::EmployeeResource) do
        def self.name
          "PORO::EmployeeResource"
        end
      end
    end

    let(:position_resource) do
      Class.new(PORO::PositionResource) do
        def self.name
          "PORO::PositionResource"
        end
      end
    end

    let!(:employee1) do
      PORO::Employee.create(first_name: "Stephen", last_name: "King", age: 60)
    end
    let!(:employee2) do
      PORO::Employee.create(first_name: "Agatha", last_name: "Christie", age: 70)
    end
 
    describe "fetching single entities" do
      it "works" do
        json = run(%|
          query {
            employee(id: "2") {
              firstName
            }
          }
        |)
        expect(json[:employee][:firstName]).to eq("Agatha")
      end

      it "can be null" do
        json = run(%|
          query {
            employee(id: "999") {
              firstName
            }
          }
        |)
        expect(json).to eq({
          employee: nil
        })
      end

      it "does not support filtering" do
        json = run(%|
          query {
            employee(id: "2", filter: { firstName: { eq: "Agatha" } }) {
              firstName
            }
          }
        |)
        expect(json[:errors][0][:message])
          .to eq("Field 'employee' doesn't accept argument 'filter'")
      end

      it "does not support sorting" do
        json = run(%|
          query {
            employee(id: "2", sort: [{ att: firstName, dir: desc }]) {
              firstName
            }
          }
        |)
        expect(json[:errors][0][:message])
          .to eq("Field 'employee' doesn't accept argument 'sort'")
      end

      it "does not support pagination" do
        json = run(%|
          query {
            employee(id: "2", page: { size: 1, number: 2 }) {
              firstName
            }
          }
        |)
        expect(json[:errors][0][:message])
          .to eq("Field 'employee' doesn't accept argument 'page'")
      end

      context "when fetching id" do
        context "and it is null" do
          before do
            resource.attribute :id, :integer do
              nil
            end
            schema!
          end

          it "renders error" do
            json = run(%|
              query {
                employees {
                  nodes {
                    id
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Cannot return null for non-nullable field POROEmployee.id")
          end
        end
      end

      context "when fetching __typename" do
        it "works" do
          json = run(%|
            query {
              employees {
                nodes {
                  __typename
                }
              }
            }
          |)
          expect(json).to eq({
            employees: {
              nodes: [
                { __typename: "POROEmployee" },
                { __typename: "POROEmployee" },
              ]
            }
          })
        end

        context "when resource.graphql_name is customized" do
          before do
            PORO::EmployeeResource.graphql_name = "CustomEmployee"
            schema!
          end

          after do
            PORO::EmployeeResource.graphql_name = nil
          end

          it "is respected" do
            json = run(%|
              query {
                employees {
                  nodes {
                    __typename
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [
                  { __typename: "CustomEmployee" },
                  { __typename: "CustomEmployee" },
                ]
              }
            })
          end
        end
      end

      context "when the graphql_entrypoint is customized" do
        before do
          resource.graphql_entrypoint = :exemplary_employees
          schema!
        end

        it "works" do
          json = run(%(
            query {
              exemplaryEmployee(id: "1") {
                firstName
              }
            }
          ))
          expect(json[:exemplaryEmployee]).to eq({
            firstName: "Stephen"
          })
        end

        it "does not expose the jsonapi type as an entrypoint" do
          json = run(%(
            query {
              employee(id: "1") {
                firstName
              }
            }
          ))
          expect(json[:errors][0][:message])
            .to eq("Field 'employee' doesn't exist on type 'Query'")
        end
      end
    end

    describe "fetching lists" do
      it "works" do
        json = run(%|
          query {
            employees {
              nodes {
                firstName
              }
            }
          }
        |)
        expect(json).to eq({
          employees: {
            nodes: [
              { firstName: "Stephen" },
              { firstName: "Agatha" }
            ]
          }
        })
      end

      it "can render every type" do
        now = Time.now
        allow(Time).to receive(:now) { now }
        json = run(%(
          query {
            employees {
              nodes {
                id
                firstName
                active
                age
                change
                createdAt
                today
                objekt
                stringies
                ints
                floats
                datetimes
                scalarArray
                objectArray
              }
            }
          }
        ))

        expect(json).to eq({
          employees: {
            nodes: [
              {
                id: "1",
                firstName: "Stephen",
                active: true,
                age: 60,
                change: 0.76,
                createdAt: now.iso8601,
                today: now.to_date.as_json,
                objekt: {foo: "bar"},
                stringies: ["foo", "bar"],
                ints: [1, 2],
                floats: [0.01, 0.02],
                datetimes: [now.iso8601, now.iso8601],
                scalarArray: [1, 2],
                objectArray: [{foo: "bar"}, {baz: "bazoo"}]
              },
              {
                id: "2",
                firstName: "Agatha",
                active: true,
                age: 70,
                change: 0.76,
                createdAt: now.iso8601,
                today: now.to_date.as_json,
                objekt: {foo: "bar"},
                stringies: ["foo", "bar"],
                ints: [1, 2],
                floats: [0.01, 0.02],
                datetimes: [now.iso8601, now.iso8601],
                scalarArray: [1, 2],
                objectArray: [{foo: "bar"}, {baz: "bazoo"}]
              }
            ]
          }
        })
      end

      context "when the graphql entrypoint is customized" do
        before do
          resource.graphql_entrypoint = :exemplary_employees
          schema!
        end
  
        it "works" do
          json = run(%(
            query {
              exemplaryEmployees {
                nodes {
                  firstName
                }
              }
            }
          ))
          expect(json).to eq({
            exemplaryEmployees: {
              nodes: [
                {firstName: "Stephen"},
                {firstName: "Agatha"}
              ]
            }
          })
        end
  
        it "does not expose the jsonapi type" do
          json = run(%(
            query {
              employees {
                nodes {
                  firstName
                }
              }
            }
          ))
          expect(json[:errors][0][:message])
            .to eq("Field 'employees' doesn't exist on type 'Query'")
        end

        context "on a relationship" do
          before do
            PORO::Position.create(title: "postitle", employee_id: employee1.id)
            resource.graphql_entrypoint = :employees
            position_resource.graphql_entrypoint = :empPositions
            schema!
          end
  
          it "is still queried via relationship name" do
            json = run(%(
              query {
                employees {
                  nodes {
                    positions {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            ))
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    positions: {
                      nodes: [{title: "postitle"}]
                    }
                  },
                  {
                    positions: {
                      nodes: []
                    }
                  }
                ]
              }
            })
          end
        end
      end

      context "when an attribute field has custom rendering" do
        before do
          resource.attribute :foo, :string do
            object.first_name.upcase
          end
          schema!
        end

        it "works" do
          json = run(%|
            query {
              employees {
                nodes {
                  foo
                }
              }
            }
          |)
          expect(json).to eq({
            employees: {
              nodes: [
                { foo: "STEPHEN" },
                { foo: "AGATHA" }
              ]
            }
          })
        end
      end

      context 'when a field is not readable' do
        before do
          resource.attribute :foo, :string, readable: false
          schema!
        end

        it 'is not part of the schema' do
          json = run(%|
            query {
              employees {
                nodes {
                  foo
                }
              }
            }
          |)
          expect(json[:errors][0][:extensions][:code]).to eq('undefinedField')
        end
      end

      context "when filtering" do
        it "works" do
          json = run(%|
            query {
              employees(filter: { firstName: { eq: "Agatha" } }) {
                nodes {
                  firstName
                }
              }
            }
          |)
          expect(json).to eq({
            employees: {
              nodes: [
                { firstName: "Agatha" }
              ]
            }
          })
        end

        context "when by id" do
          it "is a passed as a string" do
            json = run(%|
              query {
                employees(filter: { id: { eq: "2" } }) {
                  nodes {
                    firstName
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [
                  { firstName: "Agatha" }
                ]
              }
            })
          end
        end

        context "when passing an array" do
          let!(:employee3) { PORO::Employee.create(first_name: "Richard") }

          it "works" do
            json = run(%|
              query {
                employees(filter: { firstName: { eq: ["Richard", "Agatha"] } }) {
                  nodes {
                    firstName
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [
                  { firstName: "Agatha" },
                  { firstName: "Richard" }
                ]
              }
            })
          end

          context "but the filter is marked single: true" do
            before do
              resource.filter :id, single: true
              schema!
            end
  
            it "raises schema error" do
              json = run(%|
                query {
                  employees(filter: { id: { eq: [1, 3] } }) {
                    nodes {
                      id
                      firstName
                    }
                  }
                }
              |)
              expect(json[:errors][0][:message])
                .to eq("Argument 'eq' on InputObject 'POROEmployeeFilterFilterid' has an invalid value ([1, 3]). Expected type 'String'.")
            end
          end
        end

        context "when not filterable" do
          before do
            resource.attribute :first_name, :string, filterable: false
            schema!
          end
  
          it "returns schema error" do
            json = run(%|
              query {
                employees(filter: { firstName: { eq: "a" } }) {
                  nodes {
                    firstName
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("InputObject 'POROEmployeeFilter' doesn't accept argument 'firstName'")
          end
        end

        context "and there is a default filter" do
          let!(:employee3) { PORO::Employee.create(first_name: "JK") }

          before do
            resource.class_eval do
              def default_filter
                if context[:current_user] == "admin"
                  { first_name: { eq: "Stephen" } }
                else
                  { first_name: { eq: ["Agatha", "JK"] } }
                end
              end
            end
            schema!
          end

          it "applies" do
            json = run(%|
              query {
                employees {
                  nodes {
                    firstName
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [
                  { firstName: "Agatha" },
                  { firstName: "JK" },
                ]
              }
            })
            json = run(%|
              query {
                employees {
                  nodes {
                    firstName
                  }
                }
              }
            |, {}, { current_user: "admin"} )
            expect(json).to eq({
              employees: {
                nodes: [
                  { firstName: "Stephen" },
                ]
              }
            })
          end

          context "and it is overridden" do
            it "works" do
              json = run(%|
                query {
                  employees(filter: { firstName: { eq: "JK" }}) {
                    nodes {
                      firstName
                    }
                  }
                }
              |)
              expect(json).to eq({
                employees: {
                  nodes: [
                    { firstName: "JK" },
                  ]
                }
              })
            end
          end
        end

        context "when operator not supported" do
          before do
            resource.filter :first_name, only: [:prefix]
            schema!
          end
  
          it "returns error" do
            json = run(%|
              query {
                employees(filter: { firstName: { eq: "A" } }) {
                  nodes {
                    id
                    firstName
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("InputObject 'POROEmployeeFilterFilterfirstName' doesn't accept argument 'eq'")
          end
        end

        context "when filter is guarded" do
          context "and guard does not pass" do
            it "returns error" do
              do_run = lambda do
                run(%|
                  query {
                    employees(filter: { guardedFirstName: { eq: "Agatha" } }) {
                      nodes {
                        id
                        firstName
                      }
                    }
                  }
                |)
              end
              expect(&do_run)
                .to raise_error(Graphiti::Errors::InvalidAttributeAccess, /guarded_first_name/)
            end
          end

          context "and guard passes" do
            it "works as normal" do
              json = run(%|
                query {
                  employees(filter: { guardedFirstName: { eq: "Agatha" } }) {
                    nodes {
                      firstName
                    }
                  }
                }
              |, {}, { current_user: "admin" })
              expect(json).to eq({
                employees: {
                  nodes: [{
                    firstName: "Agatha"
                  }]
                }
              })
            end
          end
        end

        context "when filter has allowlist" do
          before do
            resource.filter :first_name, allow: ["Agatha"]
            schema!
          end
  
          it "works via enum" do
            json = run(%|
              query {
                employees(filter: { firstName: { eq: Agatha } }) {
                  nodes {
                    firstName
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [{firstName: "Agatha"}]
              }
            })
          end

          context "and a bad value is passed" do
            it "returns schema error" do
              json = run(%|
                query {
                  employees(filter: { firstName: { eq: "Stephen" } }) {
                    nodes {
                      firstName
                    }
                  }
                }
              |)
              expect(json[:errors][0][:extensions][:code])
                .to eq("argumentLiteralsIncompatible")
              expect(json[:errors][0][:message]).to match(/invalid value/)
            end
          end
        end

        context "when filter has denylist" do
          before do
            resource.filter :first_name, deny: ["Stephen"]
            schema!
          end
  
          context "and a good value is passed" do
            it "works" do
              json = run(%|
                query {
                  employees(filter: { firstName: { eq: "Agatha" } }) {
                    nodes {
                      firstName
                    }
                  }
                }
              |)
              expect(json).to eq({
                employees: {
                  nodes: [{firstName: "Agatha"}]
                }
              })
            end
          end

          context "and a bad value is passed" do
            it "returns error" do
              expect {
                run(%|
                  query {
                    employees(filter: { firstName: { eq: "Stephen" } }) {
                      nodes {
                        firstName
                      }
                    }
                  }
                |)
              }.to raise_error(Graphiti::Errors::InvalidFilterValue)
            end
          end
        end

        context "when a filter is required" do
          before do
            resource.filter :foo, :string, required: true do
              eq do |scope, value|
                scope[:conditions] ||= {}
                scope[:conditions][:first_name] = value
                scope
              end
            end
            schema!
          end
    
          context "and it is not passed" do
            it "raises schema error" do
              json = run(%(
                query {
                  employees {
                    nodes {
                      firstName
                    }
                  }
                }
              ))
              expect(json[:errors][0][:message])
                .to eq("Field 'employees' is missing required arguments: filter")
            end

            context "but it is a relationship foreign key" do
              context "on a has_many" do
                before do
                  resource.filter :foo, :string, required: false
                  position_resource.filter :employee_id, :integer, required: true
                  schema!
                end

                it "works" do
                  json = run(%|
                    query {
                      employees {
                        nodes {
                          positions {
                            nodes {
                              title
                            }
                          }
                        }
                      }
                    }
                  |)
                  expect(json).to eq({
                    employees: {
                      nodes: [
                        { positions: { nodes: [] } },
                        { positions: { nodes: [] } }
                      ]
                    }
                  })
                end
              end
            end
          end

          context "and it is passed" do
            it "works" do
              json = run(%|
                query {
                  employees(filter: { foo: { eq: "Agatha" } }) {
                    nodes {
                      firstName
                    }
                  }
                }
              |)
              expect(json).to eq({
                employees: {
                  nodes: [{
                    firstName: "Agatha"
                  }]
                }
              })
            end
          end
        end

        context "when custom type" do
          let!(:findme) do
            PORO::Employee.create(id: 999, first_name: "custom!")
          end
  
          before do
            type = Dry::Types::Nominal
              .new(nil)
              .constructor { |input|
                "custom!"
              }
            Graphiti::Types[:custom] = {
              read: type,
              write: type,
              params: type,
              kind: "scalar",
              description: "test",
              canonical_name: :string
            }
            resource.filter :my_custom, :custom do
              eq do |scope, value|
                scope[:conditions] ||= {}
                scope[:conditions][:first_name] = value
                scope
              end
            end
            schema!
          end
  
          after do
            Graphiti::Types.map.delete(:custom)
          end
  
          it "works" do
            json = run(%(
              query {
                employees(filter: { myCustom: { eq: "foo" } }) {
                  nodes {
                    id
                    firstName
                  }
                }
              }
            ))
            expect(json).to eq({
              employees: {
                nodes: [{
                  id: "999",
                  firstName: "custom!"
                }]
              }
            })
          end
        end

        context "when on a relationship" do
          let!(:wrong_employee) do
            PORO::Position.create title: "Wrong",
                                  employee_id: employee1.id,
                                  active: true
          end
  
          let!(:position2) do
            PORO::Position.create title: "Manager",
                                  employee_id: employee2.id
          end
  
          let!(:active) do
            PORO::Position.create title: "Engineer",
                                  employee_id: employee2.id,
                                  active: true
          end
  
          let!(:inactive) do
            PORO::Position.create title: "Old Manager",
                                  employee_id: employee2.id,
                                  active: false
          end

          it "works" do
            json = run(%|
              query {
                employees(filter: { firstName: { eq: "Agatha" } }) {
                  nodes {
                    id
                    firstName
                    positions(filter: { active: { eq: true } }) {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            |)
            expect(json[:employees]).to eq({
              nodes: [{
                id: employee2.id.to_s,
                firstName: "Agatha",
                positions: {
                  nodes: [{
                    title: "Engineer"
                  }]
                }
              }]
            })
          end
        end
      end

      context "when sorting" do
        it "works" do
          json = run(%|
            query {
              employees(sort: [{ att: firstName, dir: asc }]) {
                nodes {
                  firstName
                }
              }
            }
          |)
          expect(json).to eq({
            employees: {
              nodes: [
                { firstName: "Agatha" },
                { firstName: "Stephen" }
              ]
            }
          })
        end

        context "when attribute marked unsortable" do
          before do
            resource.attribute :first_name, :string, sortable: false
            schema!
          end

          it "returns schema error" do
            json = run(%|
              query {
                employees(sort: [{ att: firstName, dir: asc }]) {
                  nodes {
                    firstName
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Argument 'att' on InputObject 'POROEmployeeSort' has an invalid value (firstName). Expected type 'POROEmployeeSortAtt!'.")
          end
        end

        context "when attribute sort is guarded" do
          context "and the guard fails" do
            it "raises error" do
              do_run = lambda do
                json = run(%|
                  query getEmployees {
                    employees(sort: [{ att: guardedFirstName, dir: asc }]) {
                      nodes {
                        firstName
                      }
                    }
                  }
                |)
              end

              expect(&do_run).to raise_error(
                Graphiti::Errors::InvalidAttributeAccess,
                /guarded_first_name/
              )
            end
          end

          context "and the guard passes" do
            it "works as normal" do
              json = run(%|
                query {
                  employees(sort: [{ att: guardedFirstName, dir: asc }]) {
                    nodes {
                      firstName
                    }
                  }
                }
              |, {}, { current_user: "admin" })
              expect(json).to eq({
                employees: {
                  nodes: [
                    {firstName: "Agatha"},
                    {firstName: "Stephen"}
                  ]
                }
              })
            end
          end
        end

        context "when on a relationship" do
          let!(:position1) do
            PORO::Position.create(title: "A", employee_id: employee1.id)
          end
          let!(:position2) do
            PORO::Position.create(title: "C", employee_id: employee1.id)
          end
          let!(:position3) do
            PORO::Position.create(title: "B", employee_id: employee1.id)
          end
      
          it "works" do
            json = run(%|
              query {
                employees(filter: { firstName: { eq: "Stephen" } }) {
                  nodes {
                    firstName
                    positions(sort: [{ att: title, dir: desc }]) {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [{
                  firstName: "Stephen",
                  positions: {
                    nodes: [
                      {
                        title: "C"
                      },
                      {
                        title: "B"
                      },
                      {
                        title: "A"
                      }
                    ]
                  }
                }]
              }
            })
          end
        end
      end

      context "when paginating" do
        let!(:employee3) { PORO::Employee.create(first_name: "JK", age: 90) }

        def names(json)
          json[:employees][:edges].map { |e| e[:node][:firstName] }
        end

        def cursor_at(json, index)
          json[:employees][:edges][index][:cursor]
        end

        it "works" do
          json = run(%|
            query {
              employees(first: 2) {
                edges {
                  node {
                    firstName
                  }
                  cursor
                }
              }
            }
          |)
          expect(names(json)).to eq(["Stephen", "Agatha"])
          cursor = cursor_at(json, 0)
          json = run(%|
            query {
              employees(first: 2, after: "#{cursor}") {
                edges {
                  node {
                    firstName
                  }
                  cursor
                }
              }
            }
          |)
          expect(names(json)).to eq(["Agatha", "JK"])
          cursor = cursor_at(json, 1)
          json = run(%|
            query {
              employees(first: 1, before: "#{cursor}") {
                edges {
                  node {
                    firstName
                  }
                  cursor
                }
              }
            }
          |)
          expect(names(json)).to eq(["Agatha"])
        end

        it "supports pageInfo" do
          json = run(%|
            query {
              employees(first: 2) {
                nodes {
                  id
                }
                pageInfo {
                  hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
                }
              }
            }
          |)
          info = json[:employees][:pageInfo]
          expect(info[:hasNextPage]).to eq(true)
          expect(info[:hasPreviousPage]).to eq(false)
          expect(info[:startCursor]).to eq(Base64.encode64({ offset: 1 }.to_json).chomp)
          expect(info[:endCursor]).to eq(Base64.encode64({ offset: 2 }.to_json).chomp)
          json = run(%|
            query {
              employees(first: 2, after: "#{info[:endCursor]}") {
                edges {
                  node {
                    firstName
                  }
                }
                pageInfo {
                  hasNextPage
                  hasPreviousPage
                  startCursor
                  endCursor
                }
              }
            }
          |)
          info = json[:employees][:pageInfo]
          expect(info[:hasNextPage]).to eq(false)
          expect(info[:hasPreviousPage]).to eq(true)
          expect(info[:startCursor]).to eq(Base64.encode64({ offset: 3 }.to_json).chomp)
          expect(info[:endCursor]).to eq(Base64.encode64({ offset: 3 }.to_json).chomp)
        end

        context "when paginating with 'last'" do
          context "when no sort" do
            it "works" do
              expect(PORO::DB)
                .to receive(:all)
                .with(hash_including(sort: [{ id: :desc }]))
                .and_call_original
              json = run(%|
                query {
                  employees(last: 2) {
                    edges {
                      node {
                        firstName
                      }
                      cursor
                    }
                  }
                }
              |)
              expect(names(json)).to eq(["Agatha", "JK"])
            end
          end

          context "when a default sort" do
            before do
              resource.default_sort = [{ first_name: :desc }]
              schema!
            end

            it "is reversed" do
              expect(PORO::DB)
                .to receive(:all)
                .with(hash_including(sort: [{ first_name: :asc }]))
                .and_call_original
              json = run(%|
                query {
                  employees(last: 2) {
                    edges {
                      node {
                        firstName
                      }
                      cursor
                    }
                  }
                }
              |)
              expect(names(json)).to eq(["JK", "Agatha"])
            end
          end

          context "when a sort is given" do
            it "is reversed" do
              expect(PORO::DB)
                .to receive(:all)
                .with(hash_including(sort: [{ age: :asc }]))
                .and_call_original
              json = run(%|
                query {
                  employees(sort: [{ att: age, dir: desc }], last: 2) {
                    edges {
                      node {
                        firstName
                      }
                      cursor
                    }
                  }
                }
              |)
              expect(names(json)).to eq(["Agatha", "Stephen"])
            end
          end
        end

        context "on a to-many relationship" do
          let!(:position1) { PORO::Position.create(title: "one", employee_id: 1) }
          let!(:position2) { PORO::Position.create(title: "two", employee_id: 1) }

          context "when the parent is a single element" do
            it "works" do
              json = run(%|
                query {
                  employee(id: "#{employee1.id}") {
                    firstName
                    positions(first: 1) {
                      pageInfo {
                        hasNextPage
                        hasPreviousPage
                        startCursor
                        endCursor
                      }
                      edges {
                        node {
                          title
                        }
                        cursor
                      }
                    }
                  }
                }
              |)
              edges = json[:employee][:positions][:edges]
              expect(edges.map { |e| e[:node][:title ]}).to eq(['one'])
              cursor = edges[0][:cursor]
              json = run(%|
                query {
                  employee(id: "#{employee1.id}") {
                    firstName
                    positions(first: 1, after: "#{cursor}") {
                      edges {
                        node {
                          title
                        }
                        cursor
                      }
                    }
                  }
                }
              |)
              edges = json[:employee][:positions][:edges]
              expect(edges.map { |e| e[:node][:title ]}).to eq(['two'])
            end
          end

          context "when the parent is an array" do
            context "that only has one element" do
              it "works" do
                json = run(%|
                  query {
                    employees(first: 1) {
                      nodes {
                        firstName
                        positions(first: 1) {
                          pageInfo {
                            hasNextPage
                            hasPreviousPage
                            startCursor
                            endCursor
                          }
                          edges {
                            node {
                              title
                            }
                            cursor
                          }
                        }
                      }
                    }
                  }
                |)
                edges = json[:employees][:nodes][0][:positions][:edges]
                expect(edges.map { |e| e[:node][:title ]}).to eq(['one'])
                cursor = edges[0][:cursor]
                json = run(%|
                  query {
                    employees(first: 1) {
                      nodes {
                        firstName
                        positions(first: 1, after: "#{cursor}") {
                          edges {
                            node {
                              title
                            }
                            cursor
                          }
                        }
                      }
                    }
                  }
                |)
                edges = json[:employees][:nodes][0][:positions][:edges]
                expect(edges.map { |e| e[:node][:title ]}).to eq(['two'])
              end

              context "but no elements in the relationship" do
                before do
                  PORO::DB.data[:positions] = []
                end

                it "works" do
                  json = run(%|
                    query {
                      employees(first: 1) {
                        nodes {
                          firstName
                          positions(first: 1) {
                            pageInfo {
                              hasNextPage
                              hasPreviousPage
                              startCursor
                              endCursor
                            }
                            edges {
                              node {
                                title
                              }
                              cursor
                            }
                          }
                        }
                      }
                    }
                  |)
                  positions = json[:employees][:nodes][0][:positions]
                  edges = positions[:edges]
                  expect(edges.length).to be_zero
                  expect(positions[:pageInfo][:hasNextPage]).to eq(false)
                  expect(positions[:pageInfo][:hasPreviousPage]).to eq(false)
                  expect(positions[:pageInfo][:startCursor]).to be_nil
                  expect(positions[:pageInfo][:endCursor]).to be_nil
                end
              end
            end

            context "that has many elements" do
              it "raises error" do
                do_run = lambda do
                  run(%|
                    query {
                      employees {
                        nodes {
                          firstName
                          positions(first: 1) {
                            nodes {
                              title
                            }
                          }
                        }
                      }
                    }
                  |)
                end
                expect(&do_run).to raise_error(Graphiti::Errors::UnsupportedPagination)
              end
            end
          end
        end
      end

      describe "statistics" do
        context "when top-level" do
          context "when requesting built-in total count" do
            it "works" do
              json = run(%(
                query {
                  employees {
                    stats {
                      total {
                        count
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                employees: {
                  stats: {
                    total: {
                      count: 2
                    }
                  }
                }
              })
            end
          end

          context "when requesting attribute-level stat" do
            before do
              resource.stat age: [:average, :maximum]
              schema!
            end

            it "works" do
              json = run(%(
                query {
                  employees {
                    stats {
                      age {
                        average
                        maximum
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                employees: {
                  stats: {
                    age: {
                      average: 65.0,
                      maximum: 70.0
                    }
                  }
                }
              })
            end
          end

          context "when multi-word attribute" do
            before do
              resource.stat multi_word_stat: [:sum]
              schema!
            end
  
            it "works" do
              json = run(%(
                query {
                  employees {
                    nodes {
                      firstName
                    }
                    stats {
                      multiWordStat {
                        sum
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                employees: {
                  nodes: [
                    { firstName: "Stephen" },
                    { firstName: "Agatha" }
                  ],
                  stats: {
                    multiWordStat: {
                      sum: 0
                    }
                  }
                }
              })
            end
          end

          context "when no nodes requested" do
            it "automatically sends page[size]=0" do
              expect(PORO::EmployeeResource).to receive(:all).with(hash_including({
                page: {size: 0}
              })).and_call_original
              json = run(%(
                query {
                  employees {
                    stats {
                      total {
                        count
                      }
                    }
                  }
                }
              ))
            end
          end
        end
      end

      context "when requesting relationships" do
        context "has_many" do
          let!(:position1) { PORO::Position.create(title: "title1", employee_id: employee2.id) }
          let!(:position2) { PORO::Position.create(title: "title2", employee_id: employee2.id) }
          let!(:position3) { PORO::Position.create(title: "title3", employee_id: employee1.id) }

          it "works" do
            json = run(%|
              query {
                employees {
                  nodes {
                    firstName
                    positions {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    firstName: "Stephen",
                    positions: {
                      nodes: [
                        { title: "title3" }
                      ]
                    }
                  },
                  {
                    firstName: "Agatha",
                    positions: {
                      nodes: [
                        { title: "title1" },
                        { title: "title2" }
                      ]
                    }
                  }
                ]
              }
            })
          end

          it "it does not have a schema that allows filtering on FK" do
            json = run(%|
              query {
                employees {
                  nodes {
                    firstName
                    positions(filter: { employee_id: { eq: "123" } }) {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("InputObject 'POROPositionFilter' doesn't accept argument 'employee_id'")
          end

          context "when the relationship has no data" do
            before do
              PORO::Employee.create(first_name: "Jane")
            end

            it "returns an empty array" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      firstName
                      positions {
                        nodes {
                          title
                        }
                      }
                    }
                  }
                }
              |)
              expect(json[:employees][:nodes][2]).to eq({
                firstName: "Jane",
                positions: {
                  nodes: []
                }
              })
            end
          end

          it "can subquery" do
            json = run(%|
              query {
                employees {
                  nodes {
                    firstName
                    positions(filter: { title: { eq: "title3" } }) {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            |)
            positions = json[:employees][:nodes].map { |n| n[:positions][:nodes] }.flatten
            expect(positions).to eq([{ title: "title3" }])
          end

          it "forces page size 999" do
            expect(PORO::PositionResource)
              .to receive(:all)
              .with(hash_including(page: { size: 999 }))
              .and_call_original
            json = run(%|
              query {
                employees {
                  nodes {
                    positions {
                      nodes {
                        title
                      }
                    }
                  }
                }
              }
            |)
          end

          context "when manually paginating" do
            it "is respected" do
              expect(PORO::PositionResource)
                .to receive(:all)
                .with(hash_including(page: { size: 7 }))
                .and_call_original
              json = run(%|
                query {
                  employees(first: 1) {
                    nodes {
                      positions(first: 7) {
                        nodes {
                          title
                        }
                      }
                    }
                  }
                }
              |)
            end
          end

          context "when customized FK" do
            let!(:pos1) { PORO::Position.create(emp_id: employee1.id, title: "a") }
            let!(:pos2) { PORO::Position.create(emp_id: employee2.id, title: "b") }
            let!(:pos3) { PORO::Position.create(emp_id: employee2.id, title: "c") }

            before do
              position_resource.filter :emp_id, :integer
              resource.has_many :positions, foreign_key: :emp_id, resource: position_resource
              schema!
            end

            it "works" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      positions {
                        nodes {
                          title
                        }
                      }
                    }
                  }
                }
              |)
              expect(json).to eq({
                employees: {
                  nodes: [
                    {
                      positions: {
                        nodes: [{ title: "a" }]
                      }
                    },
                    {
                      positions: {
                        nodes: [
                          { title: "b" },
                          { title: "c" },
                        ]
                      }
                    }
                  ]
                }
              })
            end
          end

          context "when customized PK" do
            let!(:emp1) { PORO::Employee.create(emp_id: 91) }
            let!(:pos1) { PORO::Position.create(employee_id: 91, title: "b") }

            before do
              resource.has_many :positions, primary_key: :emp_id
              schema!
            end

            it "works" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      positions {
                        nodes {
                          title
                        }
                      }
                    }
                  }
                }
              |)
              expect(json).to eq({
                employees: {
                  nodes: [
                    { positions: { nodes: [] } },
                    { positions: { nodes: [] } },
                    { positions: { nodes: [{ title: "b" }] } }
                  ]
                }
              })
            end
          end

          context "when customized with params block" do
            xit "is honored - should we support this? what about overrides?" do
            end
          end

          context "when requesting stats" do
            let!(:employee3) { PORO::Employee.create(first_name: "Jane") }

            before do
              PORO::Position.create(employee_id: employee3.id)
              PORO::Position.create(employee_id: employee3.id)
            end

            context "and there is a single parent record" do
              it "works" do
                json = run(%|
                  query {
                    employees(filter: { id: { eq: "#{employee3.id}" } }) {
                      nodes {
                        firstName
                        positions {
                          nodes {
                            title
                          }
                          stats {
                            total {
                              count
                            }
                          }
                        }
                      }
                    }
                  }
                |)
                positions = json[:employees][:nodes][0][:positions]
                expect(positions[:stats][:total][:count]).to eq(2.0)
              end
            end
          
            context "when no nodes requested" do
              it "sets page size 0" do
                expect(PORO::PositionResource)
                  .to receive(:all).with(
                    hash_including(page: { size: 0 })
                  ).and_call_original
                json = run(%|
                  query {
                    employee(id: "#{employee3.id}") {
                      firstName
                      positions {
                        stats {
                          total {
                            count
                          }
                        }
                      }
                    }
                  }
                |)
                expect(json[:employee][:positions][:stats][:total][:count])
                  .to eq(2.0)
              end
            end

            context "when multiple parent records" do
              context "when using a group-capable adapter" do
                context "when has_many" do
                  before do
                    PORO::Position.create(employee_id: employee2.id)
                    PORO::Position.create(employee_id: employee2.id)
                    PORO::Position.create(employee_id: employee2.id)
                  end

                  it "works" do
                    json = run(%|
                      query {
                        employees {
                          nodes {
                            id
                            positions {
                              stats {
                                total {
                                  count
                                }
                              }
                            }
                          }
                        }
                      }
                    |)
                    expect(json).to eq({
                      employees: {
                        nodes: [
                          { id: "1", positions: { stats: { total: { count: 1.0 } } } },
                          { id: "2", positions: { stats: { total: { count: 5.0 } } } },
                          { id: "3", positions: { stats: { total: { count: 2.0 } } } }
                        ]
                      }
                    })
                  end

                  it "passes group_by correctly" do
                    expect(PORO::PositionResource)
                      .to receive(:all)
                      .with(hash_including(stats: { total: [:count], group_by: :employee_id }))
                      .and_call_original
                    json = run(%|
                      query {
                        employees {
                          nodes {
                            id
                            positions {
                              stats {
                                total {
                                  count
                                }
                              }
                            }
                          }
                        }
                      }
                    |)
                  end
                end

                context "when m2m" do
                  before do
                    id = PORO::Team.create.id
                    PORO::EmployeeTeam.create(team_id: id, employee_id: employee1.id)
                    4.times do
                      id = PORO::Team.create.id
                      PORO::EmployeeTeam.create(team_id: id, employee_id: employee2.id)
                    end
                    2.times do
                      id = PORO::Team.create.id
                      PORO::EmployeeTeam.create(team_id: id, employee_id: employee3.id)
                    end
                  end

                  it "works" do
                    json = run(%|
                      query {
                        employees {
                          nodes {
                            id
                            teams {
                              stats {
                                total {
                                  count
                                }
                              }
                            }
                          }
                        }
                      }
                    |)
                    expect(json).to eq({
                      employees: {
                        nodes: [
                          { id: "1", teams: { stats: { total: { count: 1.0 } } } },
                          { id: "2", teams: { stats: { total: { count: 4.0 } } } },
                          { id: "3", teams: { stats: { total: { count: 2.0 } } } }
                        ]
                      }
                    })
                  end

                  xit "passes group_by correctly" do
                  end
                end
              end

              context "when not using a group-capable adapter" do
                before do
                  allow_any_instance_of(PORO::Adapter).to receive(:can_group?) { false }
                end

                it "raises error" do
                  do_run = lambda do
                    run(%|
                      query {
                        employees {
                          nodes {
                            positions {
                              stats {
                                total {
                                  count
                                }
                              }
                            }
                          }
                        }
                      }
                    |)
                  end
                  expect(&do_run).to raise_error(GraphitiGql::Errors::UnsupportedStats)
                end
              end
            end
          end
        end

        context "belongs_to" do
          let!(:pos1) { PORO::Position.create(employee_id: employee2.id) }

          it "works" do
            json = run(%|
              query {
                positions {
                  nodes {
                    employee {
                      firstName
                    }
                  }
                }
              }
            |)
            expect(json).to eq({
              positions: {
                nodes: [{
                  employee: {
                    firstName: "Agatha"
                  }
                }]
              }
            })
          end

          context "when nil" do
            before do
              pos1.update_attributes(employee_id: nil)
            end

            it "returns nil" do
              json = run(%|
                query {
                  positions {
                    nodes {
                      employee {
                        firstName
                      }
                    }
                  }
                }
              |)
              expect(json).to eq({
                positions: {
                  nodes: [{
                    employee: nil
                  }]
                }
              })
            end

            context "when single parent" do
              it "does not query" do
                expect(PORO::EmployeeResource).to_not receive(:all)
                json = run(%|
                  query {
                    positions {
                      nodes {
                        employee {
                          firstName
                        }
                      }
                    }
                  }
                |)
              end
            end

            context "when multiple parents" do
              before do
                PORO::Position.create(employee_id: employee2.id)
              end

              it "does not query for nil" do
                expect(PORO::EmployeeResource)
                  .to receive(:all)
                  .with(hash_including(filter: { id: { eq: "2" } }))
                  .and_call_original
                json = run(%|
                  query {
                    positions {
                      nodes {
                        employee {
                          firstName
                        }
                      }
                    }
                  }
                |)
              end
            end
          end

          context "when unreadable" do
            before do
              position_resource.belongs_to :employee, readable: false
              schema!
            end

            it "is not present in the schema" do
              json = run(%|
                query {
                  positions {
                    nodes {
                      employee {
                        firstName
                      }
                    }
                  }
                }
              |)
              expect(json[:errors][0][:message])
                .to eq("Field 'employee' doesn't exist on type 'POROPosition'")
            end
          end

          context "when guarded" do
            before do
              position_resource.class_eval do
                belongs_to :employee, readable: :admin?
                def admin?
                  context[:current_user] == "admin"
                end
              end
              schema!
            end

            context "and the guard passes" do
              it "works" do
                json = run(%|
                  query {
                    positions {
                      nodes {
                        employee {
                          firstName
                        }
                      }
                    }
                  }
                |, {}, { current_user: "admin" })
                expect(json).to eq({
                  positions: {
                    nodes: [{
                      employee: {
                        firstName: "Agatha"
                      }
                    }]
                  }
                })
              end
            end

            context "and the guard fails" do
              it "raises error" do
                do_run = lambda do
                  run(%|
                    query {
                      positions {
                        nodes {
                          employee {
                            firstName
                          }
                        }
                      }
                    }
                  |, {}, { current_user: "not admin" })
                end
                expect(&do_run).to raise_error(
                  GraphitiGql::Errors::UnauthorizedField,
                  "You are not authorized to read field positions.nodes.0.employee"
                )
              end
            end
          end

          context "when custom PK" do
            let!(:emp) { PORO::Employee.create(emp_id: 87) }
            let!(:pos) { PORO::Position.create(employee_id: 87) }

            before do
              position_resource.belongs_to :employee, primary_key: :emp_id
              schema!
            end

            it "works" do
              json = run(%|
                query {
                  positions {
                    nodes {
                      employee {
                        id
                      }
                    }
                  }
                }
              |)
              expect(json).to eq({
                positions: {
                  nodes: [
                    {
                      employee: {
                        id: employee2.id.to_s
                      }
                    },
                    {
                      employee: {
                        id: "87"
                      }
                    }
                  ]
                }
              })
            end
          end

          context "when custom FK" do
            let!(:pos1) { PORO::Position.create(emp_id: 87) }

            before do
              position_resource.belongs_to :employee, foreign_key: :emp_id
              schema!
            end

            it "works" do
              json = run(%|
                query {
                  positions {
                    nodes {
                      employee {
                        id
                      }
                    }
                  }
                }
              |)
              expect(json).to eq({
                positions: {
                  nodes: [
                    {
                      employee: {
                        id: "87"
                      }
                    }
                  ]
                }
              })
            end
          end

          context "when only id requested" do
            it "works" do
              json = run(%|
                query {
                  positions {
                    nodes {
                      employee {
                        id
                        __typename
                      }
                    }
                  }
                }
              |)
              expect(json).to eq({
                positions: {
                  nodes: [
                    { employee: { id: "2", __typename: "POROEmployee" } }
                  ]
                }
              })
            end

            it "does not query" do
              expect(PORO::EmployeeResource).to_not receive(:all)
              json = run(%|
                query {
                  positions {
                    nodes {
                      employee {
                        id
                        __typename
                      }
                    }
                  }
                }
              |)
            end
          end

          it "does not support filter args" do
            json = run(%|
              query {
                positions {
                  nodes {
                    employee(filter: { firstName: { eq: "a" } }) {
                      firstName
                    }
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Field 'employee' doesn't accept argument 'filter'")
          end

          it "does not support sort args" do
            json = run(%|
              query {
                positions {
                  nodes {
                    employee(sort: [{ att: firstName, dir: asc }]) {
                      firstName
                    }
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Field 'employee' doesn't accept argument 'sort'")
          end

          it "does not support pagination args" do
            json = run(%|
              query {
                positions {
                  nodes {
                    employee(first: 2) {
                      firstName
                    }
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Field 'employee' doesn't accept argument 'first'")
          end
        end

        context "polymorphic resources" do
          let!(:visa) { PORO::Visa.create(id: 1, number: "1", employee_id: employee2.id) }
          let!(:gold_visa) { PORO::GoldVisa.create(id: 2, number: "2") }
          let!(:mastercard) { PORO::Mastercard.create(id: 3, number: "3") }

          it "can query at top level" do
            json = run(%(
              query {
                creditCards {
                  nodes {
                    id
                    __typename
                    number
                    description
                  }
                }
              }
            ))
            expect(json).to eq({
              creditCards: {
                nodes: [
                  {
                    id: "1",
                    __typename: "POROVisa",
                    number: 1,
                    description: "visa description"
                  },
                  {
                    id: "2",
                    __typename: "Goldies",
                    number: 2,
                    description: "visa description"
                  },
                  {
                    id: "3",
                    __typename: "POROMastercard",
                    number: 3,
                    description: "mastercard description"
                  }
                ]
              }
            })
          end

          context "when querying as an association" do
            it "works" do
              json = run(%(
                query {
                  employees {
                    nodes {
                      firstName
                      creditCards {
                        nodes {
                          __typename
                          number
                        }
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                employees: {
                  nodes: [
                    {
                      firstName: "Stephen",
                      creditCards: {nodes: []}
                    },
                    {
                      firstName: "Agatha",
                      creditCards: {
                        nodes: [{
                          __typename: "POROVisa", number: 1
                        }]
                      }
                    }
                  ]
                }
              })
            end

            context "and fragmenting" do
              it "works" do
                PORO::Mastercard.create(number: 77, employee_id: 2)
                json = run(%(
                  query {
                    employees {
                      nodes {
                        firstName
                        creditCards {
                          nodes {
                            __typename
                            ...on POROMastercard {
                              number
                            }
                          }
                        }
                      }
                    }
                  }
                ))
                nodes = json[:employees][:nodes][1][:creditCards][:nodes]
                expect(nodes).to eq([
                  { __typename: "POROVisa" },
                  { __typename: "POROMastercard", number: 77 }
                ])
              end
            end
          end

          context "when there is an additional association on the parent" do
            before do
              PORO::Transaction.create \
                amount: 100,
                credit_card_id: mastercard.id
            end
    
            it "can be queried via toplevel (no fragment)" do
              json = run(%(
                query {
                  creditCards {
                    nodes {
                      transactions {
                        nodes {
                          amount
                        }
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                creditCards: {
                  nodes: [
                    {transactions: {nodes: []}},
                    {transactions: {nodes: []}},
                    {transactions: {nodes: [{amount: 100}]}}
                  ]
                }
              })
            end
          end

          context "when fragmenting" do
            context "when all types share a field via the parent" do
              it "only returns the field for the *requesting fragment*" do
                json = run(%(
                  query {
                    creditCards {
                      nodes {
                        __typename
                        ...on POROMastercard {
                          number
                        }
                      }
                    }
                  }
                ))
                expect(json).to eq({
                  creditCards: {
                    nodes: [
                      {
                        __typename: "POROVisa"
                      },
                      {
                        __typename: "Goldies",
                      },
                      {
                        __typename: "POROMastercard",
                        number: 3
                      }
                    ]
                  }
                })
              end
            end

            context "when only one type has the field" do
              it "only returns the field for the requesting fragment" do
                json = run(%(
                  query {
                    creditCards {
                      nodes {
                        __typename
                        ...on POROVisa {
                          visaOnlyAttr
                        }
                      }
                    }
                  }
                ))
                expect(json).to eq({
                  creditCards: {
                    nodes: [
                      {
                        __typename: "POROVisa",
                        visaOnlyAttr: "visa only"
                      },
                      {
                        __typename: "Goldies"
                      },
                      {
                        __typename: "POROMastercard"
                      }
                    ]
                  }
                })
              end
            end

            context "when there is an additional association requested for a single fragment" do
              context "and the relationship is defined on the parent resource" do
                before do
                  PORO::Transaction.create \
                    amount: 100,
                    credit_card_id: visa.id
                  PORO::Transaction.create \
                    amount: 200,
                    credit_card_id: visa.id
                end
    
                it "works" do
                  expect_any_instance_of(PORO::TransactionResource)
                    .to receive(:resolve).and_call_original
                  json = run(%(
                    query {
                      creditCards {
                        nodes {
                          __typename
                          ...on POROVisa {
                            transactions {
                              nodes {
                                amount
                              }
                            }
                          }
                        }
                      }
                    }
                  ))
                  expect(json).to eq({
                    creditCards: {
                      nodes: [
                        {
                          __typename: "POROVisa",
                          transactions: {
                            nodes: [{amount: 100}, {amount: 200}]
                          }
                        },
                        {__typename: "Goldies" },
                        {__typename: "POROMastercard" }
                      ]
                    }
                  })
                end

                it "can filter the relationship" do
                  json = run(%(
                    query {
                      creditCards {
                        nodes {
                          __typename
                          ...on POROVisa {
                            transactions(filter: { amount: { eq: 200 } }) {
                              nodes {
                                amount
                              }
                            }
                          }
                        }
                      }
                    }
                  ))
                  expect(json).to eq({
                    creditCards: {
                      nodes: [
                        {
                          __typename: "POROVisa",
                          transactions: {nodes: [{amount: 200}]}
                        },
                        {__typename: "Goldies" },
                        {__typename: "POROMastercard" }
                      ]
                    }
                  })
                end

                it "can sort the relationship" do
                  json = run(%(
                    query {
                      creditCards {
                        nodes {
                          __typename
                          ...on POROVisa {
                            transactions(sort: [{ att: amount, dir: desc }]) {
                              nodes {
                                amount
                              }
                            }
                          }
                        }
                      }
                    }
                  ))
                  expect(json).to eq({
                    creditCards: {
                      nodes: [
                        {
                          __typename: "POROVisa",
                          transactions: {
                            nodes: [{amount: 200}, {amount: 100}]
                          }
                        },
                        {__typename: "Goldies" },
                        {__typename: "POROMastercard" }
                      ]
                    }
                  })
                end

                it "can paginate the relationship" do
                  cursor = Base64.encode64({offset: 1}.to_json)
                  json = run(%(
                    query {
                      creditCards(first: 1) {
                        nodes {
                          __typename
                          ...on POROVisa {
                            transactions(first: 1, after: "#{cursor}") {
                              nodes {
                                amount
                              }
                            }
                          }
                        }
                      }
                    }
                  ))
                  expect(json).to eq({
                    creditCards: {
                      nodes: [
                        {
                          __typename: "POROVisa",
                          transactions: {nodes: [{amount: 200}]}
                        }
                      ]
                    }
                  })
                end

                context "and the relationship is defined on multiple child resources" do
                  let!(:wrong_reward) { PORO::VisaReward.create(visa_id: 999) }
                  let!(:reward1) do
                    PORO::VisaReward.create(visa_id: gold_visa.id, points: 5)
                  end
                  let!(:reward2) do
                    PORO::VisaReward.create \
                      visa_id: gold_visa.id,
                      points: 10
                  end
                  let!(:transaction1) do
                    PORO::VisaRewardTransaction.create(amount: 100, reward_id: reward1.id)
                  end
                  let!(:transaction2) do
                    PORO::VisaRewardTransaction.create(amount: 200, reward_id: reward1.id)
                  end
      
                  def transactions(json)
                    json[:creditCards][:nodes][1][:visaRewards][:nodes][0][:rewardTransactions][:nodes]
                  end
      
                  it "works" do
                    expect_any_instance_of(PORO::VisaRewardResource)
                      .to receive(:resolve).and_call_original
                    expect_any_instance_of(PORO::VisaRewardTransactionResource)
                      .to receive(:resolve).and_call_original
                    json = run(%(
                      query {
                        creditCards {
                          nodes {
                            __typename
                            ...on Goldies {
                              visaRewards {
                                nodes {
                                  id
                                  points
                                  rewardTransactions {
                                    nodes {
                                      amount
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    ))
                    expect(transactions(json)).to eq([
                      {amount: 100},
                      {amount: 200}
                    ])
                  end

                  it "can filter the relationship off the fragment" do
                    json = run(%(
                      query {
                        creditCards {
                          nodes {
                            __typename
                            ...on Goldies {
                              visaRewards {
                                nodes {
                                  id
                                  points
                                  rewardTransactions(filter: { amount: { eq: 200 } }) {
                                    nodes {
                                      amount
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    ))
                    expect(transactions(json)).to eq([
                      {amount: 200}
                    ])
                  end

                  it "can sort the relationship off the fragment" do
                    json = run(%(
                      query {
                        creditCards {
                          nodes {
                            __typename
                            ...on Goldies {
                              visaRewards {
                                nodes {
                                  id
                                  points
                                  rewardTransactions(sort: [{ att: amount, dir: desc }]) {
                                    nodes {
                                      amount
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    ))
                    expect(transactions(json)).to eq([
                      {amount: 200},
                      {amount: 100}
                    ])
                  end

                  it "can paginate the relationship off the fragment" do
                    cursor = Base64.encode64({offset: 1}.to_json)
                    json = run(%(
                      query {
                        creditCards(first: 1, after: "#{cursor}") {
                          nodes {
                            __typename
                            ...on Goldies {
                              visaRewards(first: 1) {
                                nodes {
                                  id
                                  points
                                  rewardTransactions(first: 1, after: "#{cursor}") {
                                    nodes {
                                      amount
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    ))
                    rewards = json[:creditCards][:nodes][0][:visaRewards][:nodes][0]
                    expect(rewards[:rewardTransactions][:nodes]).to eq([
                      {amount: 200}
                    ])
                  end

                  context "and deeply nested" do
                    let!(:position) do
                      PORO::Position.create(employee_id: employee2.id)
                    end
                    let!(:nested_gold_visa) do
                      PORO::GoldVisa.create(number: "2", employee_id: employee2.id)
                    end
      
                    it "still works" do
                      json = run(%(
                        query {
                          position(id: "#{position.id}") {
                            employee {
                              firstName
                              creditCards {
                                nodes {
                                  __typename
                                  ...on Goldies {
                                    visaRewards {
                                      nodes {
                                        id
                                        points
                                        rewardTransactions {
                                          nodes {
                                            amount
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      ))
                      expect(json).to eq({
                        position: {
                          employee: {
                            firstName: "Agatha",
                            creditCards: {
                              nodes: [
                                {__typename: "POROVisa"},
                                {
                                  __typename: "Goldies",
                                  visaRewards: {
                                    nodes: [
                                      {
                                        id: reward1.id.to_s,
                                        points: 5,
                                        rewardTransactions: {
                                          nodes: [
                                            {amount: 100},
                                            {amount: 200}
                                          ]
                                        }
                                      },
                                      {
                                        id: reward2.id.to_s,
                                        points: 10,
                                        rewardTransactions: {nodes: []}
                                      }
                                    ]
                                  }
                                }
                              ]
                            }
                          }
                        }
                      })
                    end
                  end
                end

                context "and the relationship is defined only on a single child resource" do
                  let!(:bad_mile) do
                    PORO::MastercardMile.create(mastercard_id: 999)
                  end
      
                  let!(:mile) do
                    PORO::MastercardMile.create(mastercard_id: mastercard.id)
                  end
      
                  it "works" do
                    json = run(%(
                      query {
                        creditCards {
                          nodes {
                            __typename
                            ...on POROMastercard {
                              mastercardMiles {
                                nodes {
                                  id
                                  amount
                                }
                              }
                            }
                          }
                        }
                      }
                    ))
                    expect(json).to eq({
                      creditCards: {
                        nodes: [
                          {__typename: "POROVisa"},
                          {__typename: "Goldies"},
                          {
                            __typename: "POROMastercard",
                            mastercardMiles: {
                              nodes: [{
                                id: mile.id.to_s,
                                amount: 100
                              }]
                            }
                          }
                        ]
                      }
                    })
                  end
                end
              end
            end
          end
        end

        context "many_to_many" do
          let!(:employee1_team1) do
            PORO::EmployeeTeam.create(employee_id: employee1.id, team_id: team1.id)
          end

          let!(:employee1_team2) do
            PORO::EmployeeTeam.create(employee_id: employee1.id, team_id: team2.id)
          end

          let!(:employee2_team1) do
            PORO::EmployeeTeam.create(employee_id: employee2.id, team_id: team3.id)
          end

          let!(:team1) do
            PORO::Team.create(name: "Stephen's First Team")
          end

          let!(:team2) do
            PORO::Team.create(name: "Stephen's Second Team")
          end

          let!(:team3) do
            PORO::Team.create(name: "Agatha's Team")
          end

          it "works" do
            json = run(%(
              query {
                employees {
                  nodes {
                    id
                    teams {
                      nodes {
                        name
                      }
                    }
                  }
                }
              }
            ))
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    id: "1",
                    teams: {
                      nodes: [
                        { name: "Stephen's First Team" },
                        { name: "Stephen's Second Team" },
                      ]
                    }
                  },
                  {
                    id: "2",
                    teams: {
                      nodes: [
                        { name: "Agatha's Team" }
                      ]
                    }
                  }
                ]
              }
            })
          end

          it "adds page size 999" do
            expect(PORO::TeamResource)
              .to receive(:all)
              .with(hash_including(page: { size: 999 }))
              .and_call_original
            json = run(%(
              query {
                employees {
                  nodes {
                    teams {
                      nodes {
                        name
                      }
                    }
                  }
                }
              }
            ))
          end

          context "when manually paginating" do
            it "is respected" do
              expect(PORO::TeamResource)
                .to receive(:all)
                .with(hash_including(page: { size: 7 }))
                .and_call_original
              json = run(%(
                query {
                  employees(first: 1) {
                    nodes {
                      teams(first: 7) {
                        nodes {
                          name
                        }
                      }
                    }
                  }
                }
              ))
            end
          end
        end

        context "polymorphic_belongs_to" do
          let!(:team) do
            PORO::Team.create name: "A Team"
          end
          let!(:note1) do
            PORO::Note.create \
              notable_type: "PORO::Employee",
              notable_id: employee2.id
          end
          let!(:note2) do
            PORO::Note.create \
              notable_type: "PORO::Team",
              notable_id: team.id
          end
          let!(:note_resource) do
            Class.new(PORO::NoteResource) do
              def self.name
                "PORO::NoteResource"
              end
              polymorphic_belongs_to :notable do
                group_by(:notable_type) do
                  on(:"PORO::Employee")
                    .belongs_to :employee, resource: PORO::EmployeeResource
                  on(:"PORO::Team")
                    .belongs_to :team, resource: PORO::TeamResource
                end
              end
            end
          end
    
          before do
            schema!
          end
    
          it "works" do
            json = run(%(
              query {
                notes {
                  nodes {
                    id
                    notable {
                      id
                      __typename
                    }
                  }
                }
              }
            ))
            expect(json).to eq({
              notes: {
                nodes: [
                  {
                    id: note1.id.to_s,
                    notable: {
                      id: employee2.id.to_s,
                      __typename: "POROEmployee"
                    }
                  },
                  {
                    id: note2.id.to_s,
                    notable: {
                      id: team.id.to_s,
                      __typename: "POROTeam"
                    }
                  }
                ]
              }
            })
          end

          context "when relationship is nil" do
            before do
              note1.update_attributes(notable_id: nil)
            end

            it "returns nil" do
              json = run(%(
                query {
                  notes {
                    nodes {
                      id
                      notable {
                        id
                        __typename
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                notes: {
                  nodes: [
                    { id: "1", notable: nil },
                    {
                      id: "2",
                      notable: {
                        __typename: "POROTeam",
                        id: "1"
                      }
                    }
                  ]
                }
              })
            end

            it "does not query" do
              expect(PORO::EmployeeResource).to_not receive(:all)
              json = run(%(
                query {
                  notes {
                    nodes {
                      id
                      notable {
                        id
                        __typename
                      }
                    }
                  }
                }
              ))
            end
          end

          context "when custom foreign key" do
            let!(:note_resource) do
              Class.new(PORO::NoteResource) do
                def self.name
                  "PORO::NoteResource"
                end
                polymorphic_belongs_to :notable, foreign_key: :n_id do
                  group_by(:notable_type) do
                    on(:"PORO::Employee")
                      .belongs_to :employee, resource: PORO::EmployeeResource
                    on(:"PORO::Team")
                      .belongs_to :team, resource: PORO::TeamResource
                  end
                end
              end
            end

            let!(:good1) { PORO::Note.create(n_id: employee1.id, notable_type: "PORO::Employee") }
            let!(:good2) { PORO::Note.create(n_id: employee2.id, notable_type: "PORO::Employee") }

            it "still works" do
              json = run(%(
                query {
                  notes {
                    nodes {
                      id
                      notable {
                        id
                        __typename
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                notes: {
                  nodes: [
                    { id: "1", notable: nil },
                    { id: "2", notable: nil },
                    {
                      id: "3",
                      notable: {
                        id: "1",
                        __typename: "POROEmployee"
                      }
                    },
                    {
                      id: "4",
                      notable: {
                        id: "2",
                        __typename: "POROEmployee"
                      }
                    }
                  ]
                }
              })
            end
          end

          context "when custom foreign type" do
            let!(:note_resource) do
              Class.new(PORO::NoteResource) do
                def self.name
                  "PORO::NoteResource"
                end
                polymorphic_belongs_to :notable do
                  group_by(:n_type) do
                    on(:"PORO::Employee")
                      .belongs_to :employee, resource: PORO::EmployeeResource
                    on(:"PORO::Team")
                      .belongs_to :team, resource: PORO::TeamResource
                  end
                end
              end
            end

            before do
              PORO::DB.clear
              PORO::Note.create(n_type: "PORO::Employee", notable_id: employee1.id)
              PORO::Note.create(n_type: "PORO::Employee", notable_id: employee2.id)
            end

            it "still works" do
              json = run(%(
                query {
                  notes {
                    nodes {
                      id
                      notable {
                        id
                        __typename
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                notes: {
                  nodes: [
                    {
                      id: "1",
                      notable: {
                        id: "1",
                        __typename: "POROEmployee"
                      }
                    },
                    {
                      id: "2",
                      notable: {
                        id: "2",
                        __typename: "POROEmployee"
                      }
                    }
                  ]
                }
              })
            end
          end

          context "when custom primary key" do
            let!(:note_resource) do
              Class.new(PORO::NoteResource) do
                def self.name
                  "PORO::NoteResource"
                end
                polymorphic_belongs_to :notable, primary_key: :emp_id do
                  group_by(:notable_type) do
                    on(:"PORO::Employee")
                      .belongs_to :employee, resource: PORO::EmployeeResource
                    on(:"PORO::Team")
                      .belongs_to :team, resource: PORO::TeamResource
                  end
                end
              end
            end

            before do
              PORO::DB.clear
              emp1 = PORO::Employee.create(emp_id: rand(9999))
              emp2 = PORO::Employee.create(emp_id: rand(9999))
              PORO::Note.create(notable_type: "PORO::Employee", notable_id: emp1.id)
              PORO::Note.create(notable_type: "PORO::Employee", notable_id: emp2.id)
            end

            it "works" do
              json = run(%(
                query {
                  notes {
                    nodes {
                      id
                      notable {
                        id
                        __typename
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                notes: {
                  nodes: [
                    {
                      id: "1",
                      notable: {
                        id: "1",
                        __typename: "POROEmployee"
                      }
                    },
                    {
                      id: "2",
                      notable: {
                        id: "2",
                        __typename: "POROEmployee"
                      }
                    }
                  ]
                }
              })
            end
          end

          context "when fragmenting" do
            it "can load fragment-specific fields" do
              json = run(%(
                query {
                  notes {
                    nodes {
                      id
                      notable {
                        id
                        ...on POROEmployee {
                          firstName
                        }
                        ...on POROTeam {
                          __typename
                          name
                        }
                      }
                    }
                  }
                }
              ))
              expect(json).to eq({
                notes: {
                  nodes: [
                    {
                      id: note1.id.to_s,
                      notable: {
                        id: employee2.id.to_s,
                        firstName: "Agatha"
                      }
                    },
                    {
                      id: note2.id.to_s,
                      notable: {
                        id: team.id.to_s,
                        __typename: "POROTeam",
                        name: "A Team"
                      }
                    }
                  ]
                }
              })
            end

            context "when a fragment-specific relationship" do
              before do
                PORO::Position.create \
                  title: "foo",
                  employee_id: employee2.id,
                  active: true
                PORO::Position.create \
                  title: "bar",
                  employee_id: employee2.id,
                  active: false
              end
    
              def positions(json)
                json[:notes][:nodes][0][:notable][:positions][:nodes]
              end
    
              it "can load" do
                expect_any_instance_of(PORO::PositionResource)
                  .to receive(:resolve).and_call_original
                json = run(%(
                  query {
                    notes {
                      nodes {
                        id
                        notable {
                          id
                          ...on POROEmployee {
                            firstName
                            positions {
                              nodes {
                                title
                              }
                            }
                          }
                          ...on POROTeam {
                            __typename
                            name
                          }
                        }
                      }
                    }
                  }
                ))
                expect(positions(json)).to eq([
                  {title: "foo"},
                  {title: "bar"}
                ])
              end

              it "can filter a relationship off the fragment" do
                json = run(%(
                  query {
                    notes {
                      nodes {
                        id
                        notable {
                          id
                          ...on POROEmployee {
                            firstName
                            positions(filter: { active: { eq: true } }) {
                              nodes {
                                title
                              }
                            }
                          }
                          ...on POROTeam {
                            __typename
                            name
                          }
                        }
                      }
                    }
                  }
                ))
                expect(positions(json)).to eq([
                  {title: "foo"}
                ])
              end

              it "can sort a relationship off the fragment" do
                json = run(%(
                  query {
                    notes {
                      nodes {
                        id
                        notable {
                          id
                          ...on POROEmployee {
                            firstName
                            positions(sort: [{ att: title, dir: asc }]) {
                              nodes {
                                title
                              }
                            }
                          }
                          ...on POROTeam {
                            __typename
                            name
                          }
                        }
                      }
                    }
                  }
                ))
                expect(positions(json)).to eq([
                  {title: "bar"},
                  {title: "foo"}
                ])
              end

              it "can paginate a relationship off the fragment" do
                cursor = Base64.encode64({ offset: 1 }.to_json)
                json = run(%(
                  query {
                    notes {
                      nodes {
                        id
                        notable {
                          id
                          ...on POROEmployee {
                            firstName
                            positions(first: 1, after: "#{cursor}") {
                              nodes {
                                title
                              }
                            }
                          }
                          ...on POROTeam {
                            __typename
                            name
                          }
                        }
                      }
                    }
                  }
                ))
                expect(positions(json)).to eq([
                  {title: "bar"}
                ])
              end
            end
          end
        end

        context "has_one" do
          let!(:pos1) do
            PORO::Position.create(title: "a", employee_id: employee1.id)
          end

          let!(:pos2) do
            PORO::Position.create(title: "b", employee_id: employee2.id)
          end

          before do
            resource.has_one :position
            schema!
          end

          it "works" do
            json = run(%(
              query {
                employees {
                  nodes {
                    position {
                      title
                    }
                  }
                }
              }
            ))
            expect(json).to eq(
              employees: {
                nodes: [
                  { position: { title: "a" } },
                  { position: { title: "b" } },
                ]
              }
            )
          end
        end

        context "basic polymorphic has_many" do
          let!(:note1) do
            PORO::Note.create notable_id: employee2.id,
                              notable_type: "PORO::Employee",
                              body: "foo"
          end
        
          it "works" do
            json = run(%(
              query {
                employees {
                  nodes {
                    notes {
                      nodes {
                        body
                      }
                    }
                  }
                }
              }
            ))
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    notes: {nodes: []}
                  },
                  {
                    notes: {nodes: [{body: "foo"}]}
                  }
                ]
              }
            })
          end

          it "adds page size 999" do
            expect(PORO::NoteResource)
              .to receive(:all)
              .with(hash_including(page: { size: 999 }))
              .and_call_original
            json = run(%(
              query {
                employees {
                  nodes {
                    notes {
                      nodes {
                        body
                      }
                    }
                  }
                }
              }
            ))
          end

          context "when manually paginating" do
            it "is respected" do
              expect(PORO::NoteResource)
                .to receive(:all)
                .with(hash_including(page: { size: 7 }))
                .and_call_original
              json = run(%(
                query {
                  employees(first: 1) {
                    nodes {
                      notes(first: 7) {
                        nodes {
                          body
                        }
                      }
                    }
                  }
                }
              ))
            end
          end
        end

        describe "advanced polymorphic_has_many" do # porting legacy spec
          let!(:wrong_type) do
            PORO::Note.create body: "wrong",
                              notable_type: "things",
                              notable_id: employee1.id
          end
          let!(:wrong_id) do
            PORO::Note.create body: "wrong",
                              notable_type: "PORO::Employee",
                              notable_id: 999
          end
          let!(:note) do
            PORO::Note.create body: "A",
                              notable_type: "PORO::Employee",
                              notable_id: employee1.id
          end
      
          it "works" do
            json = run(%(
              query {
                employees {
                  nodes {
                    notes {
                      nodes {
                        body
                      }
                    }
                  }
                }
              }
            ))
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    notes: {
                      nodes: [{
                        body: "A"
                      }]
                    }
                  },
                  {
                    notes: {nodes: []}
                  }
                ]
              }
            })
          end

          it "can render additional relationships" do
            PORO::NoteEdit.create \
              note_id: note.id,
              modification: "mod"
            json = run(%(
              query {
                employees {
                  nodes {
                    notes {
                      nodes {
                        body
                        edits {
                          nodes {
                            modification
                          }
                        }
                      }
                    }
                  }
                }
              }
            ))
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    notes: {
                      nodes: [{
                        body: "A",
                        edits: {
                          nodes: [{
                            modification: "mod"
                          }]
                        }
                      }]
                    }
                  },
                  {
                    notes: {nodes: []}
                  }
                ]
              }
            })
          end
        end

        context "when the relationship is marked unreadable" do
          before do
            resource.has_many :positions, readable: false
            schema!
          end

          it "works" do
            json = run(%|
              query {
                employees {
                  nodes {
                    positions {
                      title
                    }
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Field 'positions' doesn't exist on type 'POROEmployee'")
          end
        end

        context "when readability is behind a guard" do
          before do
            resource.class_eval do
              has_many :positions, readable: :admin?
              def admin?
                context[:current_user] == "admin"
              end
            end
            schema!
          end

          context "and the guard passes" do
            it "works" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      positions {
                        nodes {
                          id
                        }
                      }
                    }
                  }
                }
              |, {}, { current_user: "admin" })
              expect(json).to eq({
                employees: {
                  nodes: [
                    { positions: { nodes: [] } },
                    { positions: { nodes: [] } }
                  ]
                }
              })
            end
          end

          context "and the guard fails" do
            it "raises error" do
              do_run = lambda do
                run(%|
                  query {
                    employees {
                      nodes {
                        positions {
                          nodes {
                            id
                          }
                        }
                      }
                    }
                  }
                |, {}, { current_user: "not admin" })
              end
              expect(&do_run).to raise_error(
                GraphitiGql::Errors::UnauthorizedField,
                "You are not authorized to read field employees.nodes.0.positions"
              )
            end
          end
        end
      end
    end

    describe "fetching with variables" do
      before do
        PORO::Employee.create(first_name: "Bertha")
      end

      it "works" do
        json = run(%(
          query getEmployees(
            $filter: POROEmployeeFilter!,
            $sort: [POROEmployeeSort!]
          ) {
            employees(filter: $filter, sort: $sort) {
              nodes {
                id
              }
            }
          }
        ), {
          "filter" => { "firstName" => { "eq" => ["Agatha", "Bertha"] } },
          "sort" => [{ "att" => "firstName", "dir" => "desc" }]
        })
        ids = json[:employees][:nodes].map { |n| n[:id] }
        expect(ids).to eq(["3", "2"])
      end
    end

    describe "when entrypoints defined" do
      before do
        @original = GraphitiGql.entrypoints
        GraphitiGql.entrypoints = [PORO::PositionResource]
        schema!
      end

      after do
        GraphitiGql.entrypoints = @original
      end

      it "works only for defined entrypoints" do
        json = run(%(
          query {
            employees {
              nodes {
                firstName
              }
            }
          }
        ))
        expect(json[:errors][0][:message])
          .to eq("Field 'employees' doesn't exist on type 'Query'")
        json = run(%(
          query {
            positions {
              nodes {
                title
              }
            }
          }
        ))
        expect(json).to eq({
          positions: {nodes: []}
        })
      end
    end

    context "when deprecating a field" do
      before do
        resource.attribute :foo, :string, deprecation_reason: "foo is old" do
          "foo"
        end
        schema!
      end

      it "works" do
        json = run(%(
          query {
            employees {
              nodes {
                foo
              }
            }
          }
        ))
        foo_field = GraphitiGql.schema.query
          .fields["employees"].type.of_type
          .fields["nodes"].type.of_type
          .fields["foo"]
        expect(foo_field.deprecation_reason).to eq("foo is old")
      end
    end

    context "when marking a field as not-nullable" do
      before do
        resource.attribute :foo, :string, null: false do
          nil
        end
        schema!
      end

      it "works" do
        json = run(%(
          query {
            employees {
              nodes {
                foo
              }
            }
          }
        ))
        expect(json[:errors][0][:message])
          .to eq("Cannot return null for non-nullable field POROEmployee.foo")
      end
    end

    context "when marking a field as guarded" do
      before do
        resource.class_eval do
          attribute :first_name, :string, readable: :admin?
          def admin?
            context[:current_user] == "admin"
          end
        end
        schema!
      end

      context "and the guard passes" do
        it "works" do
          json = run(%(
            query {
              employees {
                nodes {
                  firstName
                }
              }
            }
          ), {}, { current_user: "admin" })
          expect(json).to eq({
            employees: {
              nodes: [
                { firstName: "Stephen" },
                { firstName: "Agatha" }
              ]
            }
          })
        end
      end

      context "and the guard fails" do
        it "raises error" do
          do_run = lambda do
            run(%(
              query {
                employees {
                  nodes {
                    firstName
                  }
                }
              }
            ), {}, { current_user: "not admin" })
          end
          expect(&do_run).to raise_error(
            GraphitiGql::Errors::UnauthorizedField,
            'You are not authorized to read field employees.nodes.0.firstName'
          )
        end
      end
    end

    describe "when using alias_attribute" do
      before do
        resource.attribute :name, :string, alias: :first_name
        schema!
      end

      def names(json)
        json[:employees][:nodes].map { |n| n[:name] }
      end

      it "renders correctly" do
        json = run(%|
          query {
            employees {
              nodes {
                name
              }
            }
          }
        |)
        expect(names(json)).to eq(%w(Stephen Agatha))
      end

      context "when customizing rendering" do
        before do
          resource.attribute :name, :string, alias: :first_name do
            object.first_name.upcase
          end
          schema!
        end

        it "is respected" do
          json = run(%|
            query {
              employees {
                nodes {
                  name
                }
              }
            }
          |)
          expect(names(json)).to eq(%w(STEPHEN AGATHA))
        end
      end

      it "sorts correctly" do
        json = run(%|
          query {
            employees(sort: [{ att: name, dir: asc }]) {
              nodes {
                name
              }
            }
          }
        |)
        expect(names(json)).to eq(%w(Agatha Stephen))
      end

      context "when customizing the sort" do
        before do
          resource.sort_all do |scope, att, dir|
            scope[:sort] ||= []
            scope[:sort] << {:first_name => :asc}
            scope
          end
          schema!
        end

        it "is respected" do
          json = run(%|
            query {
              employees(sort: [{ att: name, dir: desc }]) {
                nodes {
                  name
                }
              }
            }
          |)
          expect(names(json)).to eq(%w(Agatha Stephen))
        end
      end

      it "filters correctly" do
        json = run(%|
          query {
            employees(filter: { name: { eq: "Agatha" } }) {
              nodes {
                name
              }
            }
          }
        |)
        expect(names(json)).to eq(%w(Agatha))
      end

      context "when customizing the filter" do
        before do
          resource.filter :name do
            eq do |scope, value|
              scope[:conditions] ||= {}
              scope[:conditions][:first_name] = "Stephen"
              scope
            end
          end
          schema!
        end

        it "is respected" do
          json = run(%|
            query {
              employees(filter: { name: { eq: "Agatha" } }) {
                nodes {
                  name
                }
              }
            }
          |)
          expect(names(json)).to eq(%w(Stephen))
        end
      end

      context "when computing stats" do
        before do
          resource.attribute :years_old, :integer, alias: :age
          resource.stat years_old: [:sum]
          schema!
        end

        it "works" do
          json = run(%|
            query {
              employees {
                edges {
                  node {
                    yearsOld
                  }
                }
                stats {
                  yearsOld {
                    sum
                  }
                }
              }
            }
          |)
          expect(json).to eq({
            employees: {
              edges: [
                {
                  node: {
                    yearsOld: 60
                  }
                },
                {
                  node: {
                    yearsOld: 70
                  }
                }
              ],
              stats: {
                yearsOld: {
                  sum: 130.0
                }
              }
            }
          })
        end

        context "when a customization" do
          before do
            resource.stat years_old: [:sum] do
              sum do |scope, attr|
                # this is 'super'
                records = PORO::DB.all(scope.except(:page, :per))
                sum = records.map { |r| r.send(attr) || 0 }.sum

                # this is customization
                sum * 100
              end
            end
            schema!
          end

          it "is respected" do
            json = run(%|
              query {
                employees {
                  edges {
                    node {
                      yearsOld
                    }
                  }
                  stats {
                    yearsOld {
                      sum
                    }
                  }
                }
              }
            |)
            expect(json[:employees][:stats]).to eq({
              yearsOld: {
                sum: 13000.0
              }
            })
          end
        end
      end
    end
  end
end