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
            employee(id: "#{gid('2')}") {
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

      it "cannot fetch value objects" do
        json = run(%|
          query {
            workingHour {
              nodes {
                id
              }
            }
          }
        |)
        expect(json[:errors][0][:message])
          .to eq("Field 'workingHour' doesn't exist on type 'Query'")
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
              exemplaryEmployee(id: "#{gid('1')}") {
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

      context "when resource is singular" do
        before do
          resource.singular = true
          schema!
        end

        it "does not accept id argument" do
          json = run(%(
            query {
              employee(id: "1") {
                firstName
              }
            }
          ))

          expect(json[:errors][0][:message])
            .to eq("Field 'employee' doesn't accept argument 'id'")
        end

        it "does not accept filter argument" do
          json = run(%(
            query {
              employee(filter: { id: { eq: "1" } }) {
                firstName
              }
            }
          ))
          expect(json[:errors][0][:message])
            .to eq("Field 'employee' doesn't accept argument 'filter'")
        end

        it "works" do
          json = run(%(
            query {
              employee {
                firstName
              }
            }
          ))
          expect(json).to eq({
            employee: {
              firstName: "Stephen"
            }
          })
        end

        context "and loaded as a belongs_to" do
          before do
            PORO::Position.create(employee_id: employee2.id)
            position_resource.belongs_to :single_employee,
              resource: resource
            schema!
          end

          it "works" do
            json = run(%(
              query {
                positions {
                  nodes {
                    singleEmployee {
                      firstName
                    }
                  }
                }
              }
            ))
            # NB - Stephen not Agatha, even though FK is Agatha
            expect(json).to eq({
              positions: {
                nodes: [
                  {
                    singleEmployee: {
                      firstName: "Stephen"
                    }
                  }
                ]
              }
            })
          end

          it "does not try to filter on foreign key" do
            expect(resource).to receive(:all)
              .with({})
              .and_call_original
            json = run(%(
              query {
                positions {
                  nodes {
                    singleEmployee {
                      firstName
                    }
                  }
                }
              }
            ))
          end
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
                id: gid(employee1.id),
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
                id: gid(employee2.id),
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

      it "cannot fetch value objects" do
        json = run(%|
          query {
            workingHours {
              nodes {
                id
              }
            }
          }
        |)
        expect(json[:errors][0][:message])
          .to eq("Field 'workingHours' doesn't exist on type 'Query'")
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

        context "when filter is null" do
          context "and allow_nil is true" do
            let!(:null_name) { PORO::Employee.create }

            before do
              resource.filter :first_name, allow_nil: true
              schema!
            end

            it "is allowed" do
              json = run(%|
                query {
                  employees(filter: { firstName: { eq: null } }) {
                    nodes {
                      id
                      firstName
                    }
                  }
                }
              |)
              expect(json[:employees][:nodes][0][:id]).to eq(gid(null_name.id))
            end
          end

          context "and allow_nil is false" do
            it "is not allowed" do
              do_run = lambda do
                run(%|
                  query {
                    employees(filter: { firstName: { eq: null } }) {
                      nodes {
                        firstName
                      }
                    }
                  }
                |)
              end
              expect(&do_run)
                .to raise_error(
                  GraphitiGql::Errors::NullFilter,
                  "Filter 'first_name' does not support null"
                )
            end
          end
        end

        context "when schema: false" do
          before do
            position_resource.filter :employee_id, schema: false
            schema!
          end

          it "does not appear in the schema" do
            json = run(%|
              query {
                positions(filter: { employeeId: { eq: "123" } }) {
                  nodes {
                    id
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("InputObject 'POROPositionFilter' doesn't accept argument 'employeeId'")
          end

          it "can still be used as association" do
            PORO::Position.create(employee_id: employee1.id)
            PORO::Position.create(employee_id: employee2.id)
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
            |)
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    positions: {
                      nodes: [
                        { id: position_resource.gid('1') }
                      ]
                    }
                  },
                  {
                    positions: {
                      nodes: [
                        { id: position_resource.gid('2') }
                      ]
                    }
                  }
                ]
              }
            })
          end
        end

        context "when by id" do
          it "is a passed as a string" do
            json = run(%|
              query {
                employees(filter: { id: { eq: "#{gid('2')}" } }) {
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
                .to eq("Argument 'eq' on InputObject 'POROEmployeeFilterFilterid' has an invalid value ([1, 3]). Expected type 'ID'.")
            end
          end
        end

        context "when filter is a boolean" do
          it "does not support arrays by default" do
            json = run(%|
              query {
                employees(filter: { active: { eq: [true, false] } }) {
                  nodes {
                    id
                  }
                }
              }
            |)
            expect(json[:errors][0][:message])
              .to eq("Argument 'eq' on InputObject 'POROEmployeeFilterFilteractive' has an invalid value ([true, false]). Expected type 'Boolean'.")
          end

          context "and single: false passed" do
            context "when overriding .attribute" do
              before do
                employee1.update_attributes(active: false)
                employee2.update_attributes(active: true)
                resource.filter :active, single: false
                schema!
              end

              it "supports arrays" do
                json = run(%|
                  query {
                    employees(filter: { active: { eq: [true, false] } }) {
                      nodes {
                        id
                      }
                    }
                  }
                |)
                expect(json)  
                  .to eq(employees: { nodes: [{ id: gid("1") }, { id: gid("2") }] })
              end
            end

            context "when one-off filter" do
              before do
                employee1.update_attributes(active: false)
                employee2.update_attributes(active: true)
                resource.filter :activity, :boolean, single: false do
                  eq do |scope, value|
                    scope[:conditions] ||= {}
                    scope[:conditions][:active] = value
                    scope
                  end
                end
                schema!
              end

              it "supports arrays" do
                json = run(%|
                  query {
                    employees(filter: { activity: { eq: [true, false] } }) {
                      nodes {
                        id
                      }
                    }
                  }
                |)
                expect(json)  
                  .to eq(employees: { nodes: [{ id: gid("1") }, { id: gid("2") }] })
              end
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
          context "via .attribute :filterable option" do
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

          context "via .filter :if option" do
            before do
              resource.filter :foo, :string, if: :admin? do
                eq do |scope, value|
                  scope[:conditions] ||= {}
                  scope[:conditions][:first_name] = value
                  scope
                end
              end
              schema!
            end

            context "and the guard passes" do
              it "works" do
                json = run(%|
                  query {
                    employees(filter: { foo: { eq: "Agatha" } }) {
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

            context "and the guard fails" do
              it "raises error" do
                do_run = lambda do
                  run(%|
                    query {
                      employees(filter: { foo: { eq: "Agatha" } }) {
                        nodes {
                          firstName
                        }
                      }
                    }
                  |, {})
                end
                expect(&do_run) 
                  .to raise_error(Graphiti::Errors::InvalidAttributeAccess)
              end
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
                  position_resource.filter :employee_id, :gid, required: true
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

              context "on a many-to-many" do
                before do
                  team_resource = Class.new(PORO::TeamResource) do
                    def self.name;"PORO::TeamResource";end
                  end
                  team_resource.filter :employee_id, required: true
                  resource.many_to_many :teams,
                    foreign_key: {employee_teams: :employee_id},
                    resource: team_resource
                  schema!
                end

                it "works" do
                  json = run(%|
                    query {
                      employees(filter: { foo: { eq: "Stephen" }}) {
                        nodes {
                          teams {
                            nodes {
                              id
                            }
                          }
                        }
                      }
                    }
                  |)
                  expect(json).to eq({
                    employees: {
                      nodes: [{ teams: { nodes: [] } }]
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

        context "when a filter group is present" do
          let(:required) { :all }

          before do
            resource.filter_group [:id, :first_name], required: required
            schema!
          end

          context "and required: :any" do
            let(:required) { :any }

            context "and no filter is passed" do
              it "raises schema error" do
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
                  .to eq("Field 'employees' is missing required arguments: filter")
              end

              it "does not mark individial fields as required in the schema" do
                field = GraphitiGql.schema.query.fields["employees"]
                id = field.arguments["filter"].type.of_type.arguments["id"]
                expect(id.type).to_not be_non_null
              end
            end

            context "but it is requested as relationship" do
              before do
                position_resource.belongs_to :employee, resource: resource
                schema!
              end

              it "does not raise schema error" do
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
                expect(json).to eq(positions: { nodes: [] })
              end
            end
          end

          context "and required: :all" do
            let(:required) { :all }

            it "marks all fields as required in the schema" do
              field = GraphitiGql.schema.query.fields["employees"]
              id = field.arguments["filter"].type.of_type.arguments["id"]
              expect(id.type).to be_non_null
            end

            context "but it is requested as relationship" do
              before do
                position_resource.belongs_to :employee, resource: resource
                schema!
              end

              # Could be passed in params block, so don't require anything
              it "does not raise schema error" do
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
                expect(json).to eq(positions: { nodes: [] })
              end
            end
          end

          context "and then unset with nil" do
            before do
              resource.filter_group nil
            end

            it "correctly unsets" do
              expect(resource.config[:grouped_filters]).to eq({})
            end
          end

          context "and then unset with empty array" do
            before do
              resource.filter_group []
            end

            it "correctly unsets" do
              expect(resource.config[:grouped_filters]).to eq({})
            end
          end
        end

        context "when string_enum type" do
          before do
            resource.attribute :foo, :string_enum, allow: ['a', 'b'] do
              object.first_name == "Stephen" ? "a" : "b"
            end
            schema!
          end

          it "is registered as an enum in the schema" do
            type = GraphitiGql::Schema.registry['POROEmployee'][:type]
            expect(type.fields["foo"].type.values.keys).to eq(%w(a b))
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
                  { foo: "a" },
                  { foo: "b" }
                ]
              }
            })
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
                  id: gid("999"),
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
                id: gid(employee2.id),
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
                  employee(id: "#{gid(employee1.id)}") {
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
                  employee(id: "#{gid(employee1.id)}") {
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

      context "when requesting value objects" do
        let(:query) do
          %|
            query {
              employees {
                nodes {
                  workingHours {
                    to
                    from
                  }
                }
              }
            }
          |
        end

        it "works" do
          json = run(query)
          expect(json).to eq({
            employees: {
              nodes: [
                {
                  workingHours: {
                    from: "default from 1",
                    to: "default to 1"
                  }
                },
                {
                  workingHours: {
                    from: "default from 2",
                    to: "default to 2"
                  }
                },
              ]
            }
          })
        end

        it "does not autogenerate id field" do
          json = run(%|
            query {
              employees {
                nodes {
                  workingHours {
                    id
                  }
                }
              }
            }
          |)
          expect(json[:errors][0][:message])
            .to eq("Field 'id' doesn't exist on type 'POROWorkingHour'")
        end

        context "when array: true" do
          before do
            resource.value_object :working_hours, array: true
            schema!
          end

          context "but fallback method returns a non-array" do
            before do
              allow_any_instance_of(PORO::Employee)
                .to receive(:working_hours) { {} }
            end

            it "raises error" do
              expect { run(query) }
                .to raise_error(Graphiti::Errors::InvalidValueObject, /value object 'working_hours' configured with array: true but returned non-array: {}/)
            end
          end
        end

        context "when explicit 'resolve'" do
          before do
            wh_resource = Class.new(PORO::WorkingHourResource) do
              def self.name;'PORO::WorkingHourResource';end

              def resolve(parent)
                [{
                  from: "from #{parent.first_name}",
                  to: "to #{parent.last_name}",
                }]
              end
            end
            resource.value_object :working_hours, resource: wh_resource
            schema!
          end

          it "is honored" do
            json = run(query)
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    workingHours: {
                      from: "from Stephen",
                      to: "to King"
                    }
                  },
                  {
                    workingHours: {
                      from: "from Agatha",
                      to: "to Christie"
                    }
                  },
                ]
              }
            })
          end

          context "that returns non-array" do
            before do
              resource.class_eval do
                def resolve(scope)
                  {}
                end
              end
              schema!
            end

            it "raises error" do
              expect { run(query) }
                .to raise_error(Graphiti::Errors::InvalidResolve)
            end
          end
        end

        context "when 'resource' passed" do
          before do
            wh_resource = Class.new(PORO::WorkingHourResource) do
              def self.name;'PORO::WorkingHourResource';end

              def resolve(parent)
                [{
                  from: "resource:",
                  to: "resource:"
                }]
              end
            end
            resource.value_object :working_hours, resource: wh_resource
            schema!
          end

          it "is honored" do
            json = run(query)
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    workingHours: {
                      from: "resource:",
                      to: "resource:"
                    }
                  },
                  {
                    workingHours: {
                      from: "resource:",
                      to: "resource:"
                    }
                  },
                ]
              }
            })
          end
        end

        context "when 'null' not passed" do
          before do
            allow_any_instance_of(PORO::Employee)
              .to receive(:working_hours) { nil }
            resource.value_object :working_hours
            schema!
          end

          context "and array: false" do
            it "can be nil" do
              json = run(query)
              expect(json).to eq({
                employees: {
                  nodes: [
                    { workingHours: nil },
                    { workingHours: nil }
                  ]
                }
              })
            end
          end
        end

        context "when 'null' passed" do
          context "and value object is array" do
            before do
              allow_any_instance_of(PORO::Employee)
                .to receive(:working_hours) { nil }
              resource.value_object :working_hours, null: false
              schema!
            end
          end

          context "and value object is not an array" do
            before do
              allow_any_instance_of(PORO::Employee)
                .to receive(:working_hours) { nil }
              resource.value_object :working_hours, null: false
              schema!
            end

            it "is honored" do
              json = run(query)
              expect(json[:errors][0][:message])
                .to eq("Cannot return null for non-nullable field POROEmployee.workingHours")
            end
          end
        end

        context "when 'deprecation_reason' passed" do
          before do
            allow_any_instance_of(PORO::Employee)
              .to receive(:working_hours) { nil }
            resource.value_object :working_hours, deprecation_reason: "foo!"
            schema!
          end

          it "is honored" do
            employees = GraphitiGql.schema.query.fields["employees"]
            node = employees.type.of_type.fields["nodes"].type.of_type
            reason = node.fields["workingHours"].deprecation_reason
            expect(reason).to eq('foo!')
          end
        end

        context "when 'alias' passed" do
          before do
            allow_any_instance_of(PORO::Employee)
              .to receive(:hours) { { from: 'foo', to: 'bar' } }
            resource.value_object :working_hours, alias: :hours
            schema!
          end

          it "works" do
            json = run(query)
            json = run(query)
            expect(json).to eq({
              employees: {
                nodes: [
                  { workingHours: { from: 'foo', to: 'bar' } },
                  { workingHours: { from: 'foo', to: 'bar' } }
                ]
              }
            })
          end
        end

        context "when readable: guarded" do
          before do
            resource.value_object :working_hours, readable: :admin?
            schema!
          end

          context "and the guard passes" do
            before do
              allow_any_instance_of(resource).to receive(:admin?) { true }
            end

            it "works" do
              expect { run(query) }.to_not raise_error
            end
          end

          context "and the guard fails" do
            before do
              allow_any_instance_of(resource).to receive(:admin?) { false }
            end

            it "raises error" do
              expect { run(query) }
                .to raise_error(Graphiti::Errors::UnreadableAttribute)
            end
          end
        end

        context "when array: true" do
          before do
            allow_any_instance_of(PORO::Employee)
              .to receive(:working_hours)
              .and_return([{ from: 'a', to: 'b' }, { from: 'c', to: 'd' }])
            resource.value_object :working_hours, array: true
            schema!
          end

          it "works" do
            json = run(query)
            expect(json).to eq({
              employees: {
                nodes: [
                  {
                    workingHours: [
                      { from: "a", to: "b" },
                      { from: "c", to: "d" },
                    ],
                  },
                  {
                    workingHours: [
                      { from: "a", to: "b" },
                      { from: "c", to: "d" },
                    ]
                  }
                ]
              }
            })
          end
        end

        context "when value object has a before_query" do
          let(:wh_resource) do
            Class.new(PORO::WorkingHourResource) do
              class << self;attr_accessor :checked;end
              def self.name;'PORO::WorkingHourResource';end

              before_query :check!

              def check!
                self.class.checked = true
              end
            end
          end

          before do
            resource.value_object :working_hours, resource: wh_resource
            schema!
          end

          it 'still fires' do
            run(query)
            expect(wh_resource.checked).to eq(true)
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
                    positions(filter: { employee_id: { eq: "#{gid('123')}" } }) {
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

          context "when foreign key is aliased" do
            before do
              position2.update_attributes(emp_id: employee2.id)
              position_resource
                .attribute :employee_id, :gid, alias: :emp_id
              schema!
            end

            it "is respected" do
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
              |)
              expect(json).to eq({
                employees: {
                  nodes: [
                    { positions: { nodes: [] } },
                    {
                      positions: {
                        nodes: [
                          { id: position_resource.gid(position2.id) }
                        ]
                      }
                    }
                  ]
                }
              })
            end
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

          context "when custom params block" do
            before do
              position1.update_attributes(active: true)
              position2.update_attributes(active: false)
              position3.update_attributes(active: true)

              $spy = OpenStruct.new
              resource.has_many :positions do
                params do |hash, employees|
                  $spy.employees = employees
                  hash[:filter][:active] = { eq: true }
                end
              end
              schema!
            end

            after do
              $spy = nil
            end

            def json
              run(%|
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

            it "is honored" do
              titles = json[:employees][:nodes].map do |n|
                n[:positions][:nodes].map { |pn| pn[:title] }
              end.flatten
              expect(titles).to match_array(['title1', 'title3'])
            end

            it "yields parent records correctly" do
              json
              expect($spy.employees).to all(be_a(PORO::Employee))
              expect($spy.employees.map(&:id))
                .to eq([employee1.id, employee2.id])
            end
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
              position_resource.filter :emp_id, :gid
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
                    employees(filter: { id: { eq: "#{gid(employee3.id)}" } }) {
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
                    employee(id: "#{gid(employee3.id)}") {
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
                          { id: gid("1"), positions: { stats: { total: { count: 1.0 } } } },
                          { id: gid("2"), positions: { stats: { total: { count: 5.0 } } } },
                          { id: gid("3"), positions: { stats: { total: { count: 2.0 } } } }
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
                          { id: gid("1"), teams: { stats: { total: { count: 1.0 } } } },
                          { id: gid("2"), teams: { stats: { total: { count: 4.0 } } } },
                          { id: gid("3"), teams: { stats: { total: { count: 2.0 } } } }
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
                  .with(hash_including(filter: { id: { eq: [gid(2)] } }))
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
                        id: gid(employee2.id)
                      }
                    },
                    {
                      employee: {
                        id: gid("87")
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
                        id: gid("87")
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
                    { employee: { id: gid("2"), __typename: "POROEmployee" } }
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

            context "but custom FK" do
              before do
                PORO::Position.create(emp_id: 87)
                position_resource.belongs_to :employee, foreign_key: :emp_id
                schema!
              end

              it "still works" do
                expect(PORO::EmployeeResource).to_not receive(:all)
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
                        employee: nil
                      },
                      {
                        employee: {
                          id: gid("87")
                        }
                      }
                    ]
                  }
                })
              end
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
                    id: PORO::VisaResource.gid("1"),
                    __typename: "POROVisa",
                    number: 1,
                    description: "visa description"
                  },
                  {
                    id: PORO::GoldVisaResource.gid("2"),
                    __typename: "Goldies",
                    number: 2,
                    description: "visa description"
                  },
                  {
                    id: PORO::MastercardResource.gid("3"),
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
                          position(id: "#{position_resource.gid(position.id)}") {
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
                                        id: PORO::VisaRewardResource.gid(reward1.id),
                                        points: 5,
                                        rewardTransactions: {
                                          nodes: [
                                            {amount: 100},
                                            {amount: 200}
                                          ]
                                        }
                                      },
                                      {
                                        id: PORO::VisaRewardResource.gid(reward2.id.to_s),
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
                                id: PORO::MastercardMileResource.gid(mile.id),
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

        # ActiveRecord-specific. Needs integration test dir
        context "many_to_many" do
          let!(:employee1_team1) do
            PORO::EmployeeTeam.create(employee_id: employee1.id, team_id: team1.id, primary: false)
          end

          let!(:employee1_team2) do
            PORO::EmployeeTeam.create(employee_id: employee1.id, team_id: team2.id, primary: true)
          end

          let!(:employee2_team1) do
            PORO::EmployeeTeam.create(employee_id: employee2.id, team_id: team3.id, primary: false)
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

          before do
            allow(PORO::Employee)
              .to receive(:reflect_on_association)
              .with(:employee_teams)
              .and_return(double(klass: PORO::EmployeeTeam))
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
                    id: gid("1"),
                    teams: {
                      nodes: [
                        { name: "Stephen's First Team" },
                        { name: "Stephen's Second Team" },
                      ]
                    }
                  },
                  {
                    id: gid("2"),
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

          context "when custom params block" do
            before do
              $spy = OpenStruct.new
              resource.many_to_many :teams, foreign_key: {employee_teams: :employee_id} do
                params do |hash, parents|
                  $spy.employees = parents
                  hash[:sort] = "-id" # TODO
                end
              end
              schema!
            end

            after do
              $spy = nil
            end

            let(:json) do
              run(%(
                query {
                  employees {
                    nodes {
                      teams {
                        nodes {
                          id
                        }
                      }
                    }
                  }
                }
              ))
            end

            it "is honored" do
              nodes = json[:employees][:nodes][0][:teams][:nodes]
              expect(nodes.map { |n| n[:id] }).to eq([
                PORO::TeamResource.gid(team2.id),
                PORO::TeamResource.gid(team1.id)
              ])
            end

            it "yields parents correctly" do
              json
              expect($spy.employees).to all(be_a(PORO::Employee))
              expect($spy.employees.map(&:id))
                .to eq([employee1.id, employee2.id])
            end
          end

          context "when metadata" do
            let(:field) { "isPrimary" }
            let(:json) do
              run(%|
                query {
                  employees {
                    nodes {
                      teams {
                        edges {
                          #{field}
                          node {
                            name
                          }
                        }
                      }
                    }
                  }
                }
              |, {}, ctx)
            end
            let(:ctx) { {} }

            let(:values) do
              json[:employees][:nodes].map do |node|
                node[:teams][:edges].map { |e| e[field.to_sym] }
              end.flatten
            end

            def setup!
              opts = {
                foreign_key: {
                  employee_teams: :employee_id
                },
                edge_resource: edge_resource
              }
              resource.many_to_many(:teams, opts)
              schema!
            end

            let(:edge_resource) do
              Class.new(PORO::ApplicationResource) do
                def self.name;'EmployeeTeamResource';end
              end
            end

            context "when the attribute is not customized" do
              let(:field) { "primary" }

              before do
                edge_resource.attribute :primary, :boolean
              end

              it "works" do
                setup!
                expect(values).to eq([false, true, false])
              end

              context "but alias is passed" do
                let(:field) { "isPrimary" }

                before do
                  edge_resource.attribute :is_primary, :boolean, alias: :primary
                end

                it "is honored" do
                  setup!
                  expect(values).to eq([false, true, false])
                end
              end
            end

            context "when the attribute is customized" do
              before do
                edge_resource.attribute :is_primary, :boolean do
                  object.primary
                end
              end

              it "works" do
                setup!
                expect(values).to eq([false, true, false])
              end
            end

            # TODO docs - :admin? gets called on child resource
            context "when guarded" do
              before do
                edge_resource.attribute :is_primary, :boolean, readable: :admin? do
                  object.primary
                end
                allow_any_instance_of(edge_resource).to receive(:admin?) { is_admin }
              end

              context "and the guard passes" do
                let(:is_admin) { true }

                it "works" do
                  setup!
                  expect(values).to eq([false, true, false])
                end
              end

              context "and the guard fails" do
                let(:is_admin) { false }

                it "raises error" do
                  setup!
                  run = -> { json }
                  expect(&run)
                    .to raise_error(
                      GraphitiGql::Errors::UnauthorizedField,
                      "You are not authorized to read field employees.nodes.0.teams.edges.0.isPrimary"
                    )
                end
              end
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
                    id: PORO::NoteResource.gid(note1.id),
                    notable: {
                      id: gid(employee2.id),
                      __typename: "POROEmployee"
                    }
                  },
                  {
                    id: PORO::NoteResource.gid(note2.id),
                    notable: {
                      id: PORO::TeamResource.gid(team.id),
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
                    { id: PORO::NoteResource.gid("1"), notable: nil },
                    {
                      id: PORO::NoteResource.gid("2"),
                      notable: {
                        __typename: "POROTeam",
                        id: PORO::TeamResource.gid("1")
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
                    { id: PORO::NoteResource.gid("1"), notable: nil },
                    { id: PORO::NoteResource.gid("2"), notable: nil },
                    {
                      id: PORO::NoteResource.gid("3"),
                      notable: {
                        id: gid("1"),
                        __typename: "POROEmployee"
                      }
                    },
                    {
                      id: PORO::NoteResource.gid("4"),
                      notable: {
                        id: gid("2"),
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
                      id: PORO::NoteResource.gid("1"),
                      notable: {
                        id: gid("1"),
                        __typename: "POROEmployee"
                      }
                    },
                    {
                      id: PORO::NoteResource.gid("2"),
                      notable: {
                        id: gid("2"),
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
                      id: PORO::NoteResource.gid("1"),
                      notable: {
                        id: gid("1"),
                        __typename: "POROEmployee"
                      }
                    },
                    {
                      id: PORO::NoteResource.gid("2"),
                      notable: {
                        id: gid("2"),
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
                      id: PORO::NoteResource.gid(note1.id),
                      notable: {
                        id: gid(employee2.id),
                        firstName: "Agatha"
                      }
                    },
                    {
                      id: PORO::NoteResource.gid(note2.id),
                      notable: {
                        id: PORO::TeamResource.gid(team.id),
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

          context "when custom params block" do
            let!(:note2) do
              PORO::Note.create notable_id: employee2.id,
                                notable_type: "PORO::Employee"
            end

            let!(:note3) do
              PORO::Note.create notable_id: employee2.id,
                                notable_type: "PORO::Employee"
            end

            before do
              $spy = OpenStruct.new
              resource.polymorphic_has_many :notes, as: :notable do
                params do |hash, parents|
                  hash[:sort] = "-id" # TODO
                  $spy.employees = parents
                end
              end
              schema!
            end

            after do
              $spy = nil
            end

            let(:json) do
              run(%(
                query {
                  employees {
                    nodes {
                      notes {
                        nodes {
                          id
                        }
                      }
                    }
                  }
                }
              ))
            end

            it "is honored" do
              nodes = json[:employees][:nodes][1][:notes][:nodes]
              expect(nodes.map { |n| n[:id] })
                .to eq(PORO::NoteResource.gid(note3.id, note2.id, note1.id))
            end

            it "yields parents correctly" do
              json
              expect($spy.employees).to all(be_a(PORO::Employee))
              expect($spy.employees.map(&:id)).to eq([
                employee1.id,
                employee2.id
              ])
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

        context "has_one" do
          let!(:pos1) do
            PORO::Position.create(rank: 2, employee_id: employee1.id)
          end
          let!(:pos2) do
            PORO::Position.create(rank: 1, employee_id: employee1.id)
          end
          let!(:pos3) do
            PORO::Position.create(rank: 3, employee_id: employee1.id)
          end

          before do
            resource.has_one :top_position,
              resource: PORO::PositionResource,
              foreign_key: :employee_id
            schema!
          end

          let(:json) do
            json = run(%|
              query {
                employees {
                  nodes {
                    topPosition {
                      id
                      title
                    }
                  }
                }
              }
            |)
          end

          it "automatically limits to single record" do
            node =  json[:employees][:nodes][0]
            expect(node[:topPosition][:id]).to eq(position_resource.gid(pos1.id))
          end

          context "when custom params proc" do
            before do
              opts = {
                resource: PORO::PositionResource,
                foreign_key: :employee_id
              }
              $spy = OpenStruct.new
              resource.has_one :top_position, opts do
                params do |hash, parents|
                  $spy.employees = parents
                  hash[:filter][:rank] = { eq: 1 }
                end
              end
              schema!
            end

            after do
              $spy = nil
            end

            it "is honored" do
              node =  json[:employees][:nodes][0]
              expect(node[:topPosition][:id]).to eq(position_resource.gid(pos2.id))
            end

            it "yields parents correctly" do
              json
              expect($spy.employees).to all(be_a(PORO::Employee))
              expect($spy.employees.map(&:id)).to eq([
                employee1.id,
                employee2.id
              ])
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
        expect(ids).to eq([gid("3"), gid("2")])
      end
    end

    describe "when entrypoint disabled" do
      before do
        resource.graphql_entrypoint = false
        schema!
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

    describe "custom types" do
      let!(:employee) { PORO::Employee.create(age: 45) }

      before do
        definition = Dry::Types::Nominal.new(Integer)
        _out = definition.constructor do |input|
          input * 10
        end
      
        _in = definition.constructor do |input|
          input.to_i / 10
        end
      
        # Register it with Graphiti
        Graphiti::Types[:foo_type] = {
          params: _in,
          read: _out,
          write: _in,
          kind: 'scalar',
          canonical_name: :integer,
          graphql_type: String,
          description: 'Integer renders as string'
        }
      end

      after do
        Graphiti::Types.map.delete(:foo_type)
      end

      context "when graphql_type is specified" do
        before do
          # register foo type with gql type integer
          resource.attribute :foo, :foo_type, alias: :age
          schema!
        end

        context "when reading" do
          it "has the right type in the schema" do
            registered = GraphitiGql::Schema.registry["POROEmployee"]
            employee_type = registered[:type]
            foo_type = employee_type.fields["foo"].type
            expect(foo_type).to eq(GraphQL::Types::String)
          end

          it "is respected" do
            json = run(%|
              query {
                employees {
                  edges {
                    node {
                      foo
                    }
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                edges: [
                  { node: { foo: "600" } },
                  { node: { foo: "700" } },
                  { node: { foo: "450" } }
                ]
              }
            })
          end
        end

        context "when filtering" do
          it "is respected" do
            json = run(%|
              query {
                employees(filter: { foo: { eq: "700" } }) {
                  edges {
                    node {
                      foo
                    }
                  }
                }
              }
            |)
            expect(json).to eq({
              employees: {
                edges: [
                  { node: { foo: "700" } }
                ]
              }
            })
          end
        end
      end
    end

    describe "Resource.before_query" do
      before do
        resource.class_eval do
          class << self;attr_accessor :before_queries;end
          def check1!
            self.class.before_queries ||= []
            self.class.before_queries << :check1!
          end
          def check2!
            self.class.before_queries ||= []
            self.class.before_queries << :check2!
          end
          def check3!
            self.class.before_queries ||= []
            self.class.before_queries << :check3!
          end
        end
        resource.before_query :check1!
        schema!
      end

      def run!
        run(%|
          query {
            employees {
              nodes {
                id
              }
            }
          }
        |)
      end

      it "fires before the query" do
        run!
        expect(resource.before_queries).to eq([:check1!])
      end

      context "when if" do
        before do
          allow_any_instance_of(resource).to receive(:check2?) { pass }
          resource.before_query :check2!, if: :check2?
          schema!
        end

        context "and the check passes" do
          let(:pass) { true }

          it "works" do
            run!
            expect(resource.before_queries).to eq([:check1!, :check2!])
          end
        end

        context "and the check fails" do
          let(:pass) { false }

          it "does not fire" do
            run!
            expect(resource.before_queries).to eq([:check1!])
          end
        end
      end

      context "when unless" do
        before do
          allow_any_instance_of(resource).to receive(:check2?) { pass }
          resource.before_query :check2!, unless: :check2?
          schema!
        end

        context "and the check passes" do
          let(:pass) { true }

          it "does not fire" do
            run!
            expect(resource.before_queries).to eq([:check1!])
          end
        end

        context "and the check fails" do
          let(:pass) { false }

          it "works" do
            run!
            expect(resource.before_queries).to eq([:check1!, :check2!])
          end
        end
      end

      context "when multiple" do
        before do
          resource.before_query :check2!
          resource.before_query :check3!
        end

        it "fires each in order" do
          run!
          expect(resource.before_queries)
            .to eq([:check1!, :check2!, :check3!])
        end
      end
    end

    describe "Resource#selections" do
      def apply(resource, attr = :selections)
        $spy = OpenStruct.new
        old = resource.new.method(:resolve)
        resource.define_method :resolve do |scope|
          $spy.send(:"#{attr}=", selections)
          instance_exec(scope, &old)
        end
        schema!
      end

      after do
        $spy = nil
      end

      context "when top-level" do
        before do
          apply(resource)
        end

        context "when single entity" do
          it "works" do
            run(%|
              query {
                employee(id: "#{gid(employee1.id)}") {
                  firstName
                  age
                }
              }
            |)
            expect($spy.selections).to eq([:first_name, :age])
          end
        end

        context "when list" do
          context "via nodes" do
            it "works" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      id
                      firstName
                    }
                  }
                }
              |)
              expect($spy.selections).to eq([:id, :first_name])
            end
          end

          context "via edges" do
            it "works" do
              json = run(%|
                query {
                  employees {
                    edges {
                      node {
                        id
                        firstName
                      }
                    }
                  }
                }
              |)
              expect($spy.selections).to eq([:id, :first_name])
            end
          end
        end
      end

      context "when association" do
        context "when has_many" do
          let!(:position) do
            PORO::Position.create(employee_id: employee1.id)
          end

          before do
            apply(position_resource)
          end

          context "via nodes" do
            it "works" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      positions {
                        nodes {
                          title
                          active
                          rank
                        }
                      }
                    }
                  }
                }
              |)
              expect($spy.selections).to eq([:title, :active, :rank])
            end
          end

          context "via edges" do
            it "works" do
              json = run(%|
                query {
                  employees {
                    nodes {
                      positions {
                        edges {
                          node {
                            title
                            active
                            rank
                          }
                        }
                      }
                    }
                  }
                }
              |)
              expect($spy.selections).to eq([:title, :active, :rank])
            end
          end
        end

        context "when belongs_to" do
          before do
            PORO::Position.create(employee_id: employee1.id)
            apply(resource)
          end

          it "works" do
            json = run(%|
              query {
                positions {
                  nodes {
                    employee {
                      id
                      lastName
                      age
                    }
                  }
                }
              }
            |)
            expect($spy.selections).to eq([:id, :last_name, :age])
          end
        end

        context "when polymorphic" do
          let!(:visa) { PORO::Visa.create(id: 1, number: "1", employee_id: employee2.id) }
          let!(:gold_visa) { PORO::GoldVisa.create(id: 2, number: "2") }
          let!(:mastercard) { PORO::Mastercard.create(id: 3, number: "3") }

          before do
            $spy = OpenStruct.new
            PORO::CreditCardResource.resolve_hook = ->(instance) {
              $spy.selections = instance.selections
            }
            schema!
          end

          context "when not fragmenting" do
            it "works" do
              json = run(%|
                query {
                  creditCards {
                    nodes {
                      id
                      number
                    }
                  }
                }
              |)
              expect($spy.selections).to eq([:id, :number])
            end
          end

          context "when fragmenting on common field" do
            it "works" do
              json = run(%|
                query {
                  creditCards {
                    nodes {
                      id
                      description
                      ...on POROMastercard {
                        number
                      }
                    }
                  }
                }
              |)
              expect($spy.selections).to eq([:id, :description, :number])
            end
          end

          context "when fragmenting on type-specific field" do
            it "works" do
              json = run(%|
                query {
                  creditCards {
                    nodes {
                      id
                      description
                      ...on POROVisa {
                        visaOnlyAttr
                      }
                    }
                  }
                }
              |)
              expect($spy.selections)
                .to eq([:id, :description, :visa_only_attr])
            end
          end
        end

        context "when deeply nested with siblings" do
          before do
            dept = PORO::Department.create
            PORO::Position.create \
              employee_id: employee1.id,
              department_id: dept.id
            department_resource = Class.new(PORO::DepartmentResource) do
              def self.name;"PORO::DepartmentResource";end
            end
            team_resource = Class.new(PORO::TeamResource) do
              def self.name;"PORO::TeamResource";end
            end
            apply(resource, :employee_selections)
            apply(position_resource, :position_selections)
            apply(department_resource, :department_selections)
            apply(team_resource, :team_selections)
          end

          it "works" do
            json = run(%|
              query {
                employees {
                  nodes {
                    firstName
                    age
                    teams {
                      nodes {
                        name
                        __typename
                      }
                    }
                    positions {
                      nodes {
                        title
                        rank
                        department {
                          id
                          name
                        }
                      }
                    }
                  }
                }
              }
            |)
            expect($spy.employee_selections)
              .to eq([:first_name, :age, :teams, :positions])
            expect($spy.position_selections)
              .to eq([:title, :rank, :department])
            expect($spy.department_selections)
              .to eq([:id, :name])
            expect($spy.team_selections)
              .to eq([:name, :__typename])
          end
        end
      end
    end

    describe "Resource#filterings" do
      before do
        position_resource.class_eval do
          class << self;attr_accessor :spy_filterings;end
          alias :original_base_scope :base_scope
          def base_scope
            self.class.spy_filterings = filterings
            original_base_scope
          end
        end
        schema!
      end

      it "reflects the filters passed to .all" do
        run(%|
          query {
            positions(
              filter: {
                title: { eq: "foo" },
                rank: { gt: 10 }
              }) {
              nodes {
                id
              }
            }
          }
        |)
        expect(position_resource.spy_filterings)
          .to match_array([:title, :rank])
      end

      context "when loading as relationship" do
        it "contains under-the-hood filters" do
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
          |)
          expect(position_resource.spy_filterings)
            .to match_array([:employee_id])
        end

        context "and also given runtime filters" do
          it "merges them in" do
            run(%|
              query {
                employees {
                  nodes {
                    positions(
                      filter: {
                        title: { eq: "asdf" },
                        rank: { gt: 10 }
                      }
                    ) {
                      nodes {
                        id
                      }
                    }
                  }
                }
              }
            |)
            expect(position_resource.spy_filterings)
              .to match_array([:employee_id, :title, :rank])
          end
        end
      end
    end

    describe "Resource#parent_field" do
      before do
        position_resource.class_eval do
          class << self;attr_accessor :spy_parent_field;end
          alias :original_base_scope :base_scope
          def base_scope
            self.class.spy_parent_field = parent_field
            original_base_scope
          end
        end
        schema!
      end

      context "when loaded top-level" do
        it "is Query" do
          json = run(%|
            query {
              positions {
                nodes {
                  id
                }
              }
            }
          |)
          spy = position_resource.spy_parent_field
          expect(spy <= GraphQL::Schema::Object).to eq(true)
          expect(spy.graphql_name).to eq('Query')
        end

        context "when loaded as relationship" do
          it "returns the parent GQL field" do
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
            |)
            spy = position_resource.spy_parent_field
            expect(spy <= GraphQL::Schema::Object).to eq(true)
            expect(spy.graphql_name).to eq('POROEmployee')
          end
        end
      end
    end

    describe "context" do
      context "when set beforehand" do
        before do
          Graphiti.context = { object: { foo: "bar" } }
          $spy = OpenStruct.new
          resource.class_eval do
            def resolve(scope)
              $spy.context = context
              super
            end
          end
          schema!
        end

        after do
          $spy = nil
          Graphiti.context = {}
        end

        it "is used" do
          run(%|
            query {
              employees {
                nodes {
                  id
                }
              }
            }
          |)
          expect($spy.context).to eq(foo: "bar")
        end

        context "but manually supplied" do
          it "chooses manual" do
            run(%|
              query {
                employees {
                  nodes {
                    id
                  }
                }
              }
            |, {}, { bar: "baz" })
            expect($spy.context).to eq(bar: "baz")
          end
        end
      end
    end

    describe "error handling" do
      let(:query) do
        %|
          query {
            employees {
              nodes {
                id
              }
            }
          }
        |
      end

      let(:handler) { Class.new(GraphitiGql::ExceptionHandler) }
      let(:custom_error_class) do
        Class.new(StandardError) do
          def message
            "message from custom error class"
          end
        end
      end

      before do
        _err = custom_error_class
        resource.define_method :resolve do |scope|
          raise(_err)
        end
        GraphitiGql.config.exception_handler = handler
        schema!
      end

      # TODO test vs dev
      # TODO internal dev deets
      context "when turned on" do
        before do
          GraphitiGql.config.error_handling = true
        end

        context "when any random error" do
          it "is returned with generic payload" do
            json = run(query)
            expect(json).to eq({
              data: nil,
              errors: [{
                message: "We're sorry, something went wrong.",
                path: ["employees"],
                extensions: { code: 500 },
                locations: [{ column: 13, line: 3 }]
              }]
            })
          end

          it "notifies" do
            expect_any_instance_of(handler).to receive(:notify)
            run(query)
          end

          it "logs" do
            expect_any_instance_of(handler).to receive(:log)
            run(query)
          end

          context "and default message is customized" do
            before do
              handler.default_message = "foo!"
            end

            it "is honored" do
              json = run(query)
              expect(json[:errors][0][:message]).to eq('foo!')
            end
          end

          context "and default code is customized" do
            before do
              handler.default_code = "code!"
            end

            it "is honored" do
              json = run(query)
              expect(json[:errors][0][:extensions][:code]).to eq('code!')
            end
          end

          context 'when notify: false' do
            before do
              handler.register_exception(custom_error_class, notify: false)
            end

            it "does not notify" do
              expect_any_instance_of(handler).to_not receive(:notify)
              json = run(query)
            end

            it "does not apply to other errors" do
              resource.define_method :resolve do |scope|
                raise('foo')
              end
              expect_any_instance_of(handler).to receive(:notify)
              json = run(query)
            end
          end

          context 'when log: false' do
            before do
              handler.register_exception(custom_error_class, log: false)
            end

            it "does not log" do
              expect_any_instance_of(handler).to_not receive(:log)
              json = run(query)
            end

            it "does not apply to other errors" do
              resource.define_method :resolve do |scope|
                raise('foo')
              end
              expect_any_instance_of(handler).to receive(:log)
              json = run(query)
            end
          end

          context "when custom code" do
            before do
              handler.register_exception(custom_error_class, code: 403)
            end

            it "is respected" do
              json = run(query)
              expect(json[:errors][0][:extensions][:code]).to eq(403)
            end

            it "does not apply to other errors" do
              resource.define_method :resolve do |scope|
                raise('foo')
              end
            end
          end
        end
      end

      context "when turned off" do
        before do
          GraphitiGql.config.error_handling = false
        end

        it "raises error" do
          expect { run(query) }.to raise_error(/message from custom error class/)
        end
      end
    end

    describe "inspector" do
      before do
        PORO::Position.create(employee_id: employee1.id, title: 'adsf')
        PORO::Position.create(employee_id: employee2.id, title: 'zzxfd')
      end

      let(:query) do
        %|
          query {
            employees {
              nodes {
                id
                firstName
                lastName
                positions {
                  nodes {
                    id
                    title
                  }
                }
              }
            }
          }
        |
      end

      it "works" do
        run(query)
      end
    end
  end
end