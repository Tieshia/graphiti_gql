require "active_model"

module PORO
  class DB
    class << self
      def data
        @data ||=
          {
            employees: [],
            positions: [],
            departments: [],
            classifications: [],
            bios: [],
            team_memberships: [],
            teams: [],
            paypals: [],
            visas: [],
            gold_visas: [],
            mastercards: [],
            visa_rewards: [],
            visa_reward_transactions: [],
            mastercard_miles: [],
            books: [],
            states: [],
            notes: [],
            note_edits: [],
            transactions: [],
            employee_teams: [],
          }
      end

      def clear
        data.each_pair do |key, value|
          data[key] = []
        end
      end

      def klasses
        {
          employees: PORO::Employee,
          positions: PORO::Position,
          departments: PORO::Department,
          classifications: PORO::Classification,
          bios: PORO::Bio,
          teams: PORO::Team,
          paypals: PORO::Paypal,
          visas: PORO::Visa,
          gold_visas: PORO::GoldVisa,
          mastercards: PORO::Mastercard,
          visa_rewards: PORO::VisaReward,
          visa_reward_transactions: PORO::VisaRewardTransaction,
          mastercard_miles: PORO::MastercardMile,
          books: PORO::Book,
          states: PORO::State,
          notes: PORO::Note,
          note_edits: PORO::NoteEdit,
          transactions: PORO::Transaction,
          employee_teams: PORO::EmployeeTeam
        }
      end

      def all(params)
        target_types = params[:type]
        records = data.select { |k, v| Array(target_types).include?(k) }
        return [] unless records
        records = records.map { |type, records_for_type|
          records_for_type.map { |attrs| klasses[type].new(attrs) }
        }.flatten
        records = apply_filtering(records, params)
        records = apply_sorting(records, params)
        apply_pagination(records, params)
      end

      private

      # TODO: the integer casting here should go away with attribute types
      def apply_filtering(records, params)
        return records unless params[:conditions]
        records.select! do |record|
          params[:conditions].all? do |key, value|
            db_value = record.send(key) if record.respond_to?(key)
            if key == :id
              value = value.is_a?(Array) ? value.map(&:to_i) : value.to_i
            end
            if value.is_a?(Array)
              value.include?(db_value)
            else
              db_value == value
            end
          end
        end
        records
      end

      def apply_sorting(records, params)
        return records if params[:sort].nil?

        params[:sort].reverse_each do |sort|
          begin
            records.sort! do |a, b|
              att = sort.keys[0]
              a.send(att) <=> b.send(att)
            end
          rescue
            binding.pry
          end
          records = records.reverse if sort.values[0] == :desc
        end
        records
      end

      def apply_pagination(records, params)
        return records unless params[:per]
        records = records[params[:offset]..records.length] if params[:offset]

        start_at = (params[:page] - 1) * (params[:per])
        end_at = (params[:page] * params[:per]) - 1
        return [] if end_at < 0
        records[start_at..end_at]
      end
    end
  end

  class Base
    include ActiveModel::Validations
    attr_accessor :id

    def self.create(attrs = {})
      record = new(attrs)

      if record.valid?
        id = attrs[:id] || DB.data[type].length + 1
        attrs[:id] = id
        record.id = id
        DB.data[type] << attrs
      end

      record
    end

    def self.find(id)
      raw = DB.data[type].find { |r| r[:id] == id }
      new(raw) if raw
    end

    def self.type
      name.underscore.pluralize.split("/").last.to_sym
    end

    def initialize(attrs = {})
      attrs.each_pair { |k, v| send(:"#{k}=", v) }
    end

    def update_attributes(attrs)
      attrs.each_pair { |k, v| send(:"#{k}=", v) }

      if valid?
        record = DB.data[self.class.type].find { |r| r[:id] == id }
        record.merge!(attrs)
        true
      else
        false
      end
    end

    def destroy
      DB.data[self.class.type]
        .delete_if { |r| r[:id] == id }
    end

    def attributes
      {}.tap do |attrs|
        instance_variables.each do |iv|
          key = iv.to_s.delete("@").to_sym
          next if key.to_s.starts_with?("__")
          value = instance_variable_get(iv)
          attrs[key] = value
        end
      end
    end

    def save
      record = DB.data[self.class.type].find { |r| r[:id] == id }
      if record
        update_attributes(attributes)
      else
        record = self.class.create(attributes)
        self.id = record.id
        valid?
      end
    end
  end

  class Employee < Base
    attr_accessor :first_name,
      :last_name,
      :age,
      :active,
      :positions,
      :current_position,
      :bio,
      :teams,
      :classification,
      :classification_id,
      :credit_card,
      :credit_cards,
      :credit_card_id,
      :cc_id,
      :credit_card_type,
      :payment_processor,
      :salary,
      :foo_positions,
      :notes,
      :other_position_id,
      :other_pos_id,
      :multi_word_stat,
      :emp_id

    def initialize(*)
      super
      @positions ||= []
      @teams ||= []
    end
  end

  class Position < Base
    attr_accessor :title,
      :active,
      :rank,
      :employee_id,
      :emp_id,
      :employee,
      :department_id,
      :department,
      :other_employee_id,
      :other_emp_id
  end

  class Classification < Base
    attr_accessor :description
  end

  class Department < Base
    attr_accessor :name, :teams
  end

  class Note < Base
    attr_accessor :body, :notable, :notable_id, :notable_type, :edits, :n_id, :n_type
  end

  class NoteEdit < Base
    attr_accessor :note, :note_id, :modification
  end

  class Bio < Base
    attr_accessor :text, :employee_id, :employee
  end

  class TeamMembership < Base
    attr_accessor :employee_id, :team_id
  end

  class Team < Base
    attr_accessor :name, :team_memberships, :department_id, :employee_teams,
      :_edge_primary,
      :_edge_employee_id,
      :_edge_team_id,
      :_edge_id
  end

  class EmployeeTeam < Base
    attr_accessor :employee_id, :team_id, :primary
  end

  class CreditCard < Base
    attr_accessor :number, :description, :employee_id, :transactions
  end

  class Transaction < Base
    attr_accessor :amount, :credit_card_id
  end

  class Visa < CreditCard
    attr_accessor :visa_only_attr
    attr_accessor :visa_rewards

    def initialize(*)
      super
      @visa_only_attr ||= nil
      @visa_rewards ||= []
    end
  end

  class GoldVisa < Visa
  end

  class Mastercard < CreditCard
    attr_accessor :mastercard_miles
  end

  class MastercardMile < Base
    attr_accessor :amount, :mastercard_id
  end

  class VisaReward < Base
    attr_accessor :visa_id, :points, :reward_transactions
  end

  class VisaRewardTransaction < Base
    attr_accessor :amount, :reward_id
  end

  class Paypal < Base
    attr_accessor :account_id
  end

  class Book < Base
    attr_accessor :title, :author_id
  end

  class State < Base
    attr_accessor :name
  end

  class Adapter < Graphiti::Adapters::Null
    def order(scope, att, dir)
      scope[:sort] ||= []
      scope[:sort] << {att => dir}
      scope
    end

    def base_scope(model)
      {}
    end

    def paginate(scope, current_page, per_page, offset)
      scope[:page] = current_page if current_page
      scope[:per] = per_page if per_page
      scope[:offset] = offset if offset
      scope
    end

    def filter(scope, name, value)
      scope[:conditions] ||= {}
      scope[:conditions][name] = value
      scope
    end
    alias_method :filter_integer_eq, :filter
    alias_method :filter_string_eq, :filter
    alias_method :filter_big_decimal_eq, :filter
    alias_method :filter_float_eq, :filter
    alias_method :filter_date_eq, :filter
    alias_method :filter_datetime_eq, :filter
    alias_method :filter_boolean_eq, :filter
    alias_method :filter_hash_eq, :filter
    alias_method :filter_array_eq, :filter

    def filter_string_prefix(scope, name, value)
      raise "Not implemented, just used for required filter test"
    end

    # No need for actual logic to fire
    def count(scope, attr)
      records = DB.all(scope.except(:page, :per))
      if scope[:group_by]
        hash = {}
        records.group_by(&scope[:group_by]).each do |key, value|
          hash[key] = value.length
        end
        hash
      else
        records.length
      end
    end

    def sum(scope, attr)
      records = DB.all(scope.except(:page, :per))
      records.map { |r| r.send(attr) || 0 }.sum
    end

    def average(scope, attr)
      sum(scope, attr) / count(scope, attr)
    end

    def maximum(scope, attr)
      records = DB.all(scope.except(:page, :per))
      records.map { |r| r.send(attr) || 0 }.max
    end

    def minimum(scope, attr)
      "poro_minimum_#{attr}"
    end

    def create(model, attributes)
      model.create(attributes)
    end

    def resolve(scope)
      ::PORO::DB.all(scope)
    end

    def save(model_instance)
      model_instance.save
      model_instance
    end

    def destroy(model_instance)
      model_instance.destroy
      model_instance
    end

    def can_group?
      true
    end

    def group(scope, name)
      scope[:group_by] = name
      scope
    end
  end

  class EmployeeSerializer < Graphiti::Serializer
    extra_attribute :stack_ranking do
      rand(999)
    end

    is_admin = proc { |c| @context && @context.current_user == "admin" }
    extra_attribute :admin_stack_ranking, if: is_admin do
      rand(999)
    end

    extra_attribute :runtime_id do
      @context.runtime_id
    end
  end

  class ApplicationResource < Graphiti::Resource
    self.adapter = Adapter
    self.abstract_class = true

    def base_scope
      {type: model.name.demodulize.underscore.pluralize.to_sym}
    end
  end

  class TeamResource < ApplicationResource
    attribute :name, :string
    filter :department_id, :integer

    filter :employee_id, :integer

    stat total: [:count] do
      count do |scope, attr|
        records = PORO::TeamResource.new.resolve(scope)
        hash = {}
        scope[:conditions][:employee_id].each do |id|
          hash[id] = PORO::DB.all(type: :employee_teams, conditions: { employee_id: id }).length
        end
        hash
      end
    end

    # Fake-out m2m resolution
    def resolve(scope)
      if scope[:conditions].key?(:employee_id)
        employee_ids = scope[:conditions][:employee_id]
        employee_team_data = PORO::DB.data[:employee_teams].select do |et|
          employee_ids.include?(et[:employee_id])
        end
        employee_teams = employee_team_data.map { |d| PORO::EmployeeTeam.new(d) }
        team_ids = employee_teams.map(&:team_id)
        team_data = PORO::DB.data[:teams].select { |t| team_ids.include?(t[:id]) }
        teams = team_data.map { |d| PORO::Team.new(d) }
        teams.each do |team|
          employee_team = employee_teams.find { |et| et.team_id == team.id }
          employee_team.attributes.each_pair do |key, value|
            prop = "_edge_#{key}"
            team.send("#{prop}=", value)
          end
        end

        if scope[:sort] == [{ id: :desc }]
          teams.reverse!
        end

        teams
      else
        super
      end
    end
  end

  class EmployeeResource < ApplicationResource
    self.serializer = PORO::EmployeeSerializer
    attribute :created_at, :datetime do
      Time.now
    end
    attribute :today, :date do
      Time.now
    end

    attribute :first_name, :string
    attribute :last_name, :string
    attribute :age, :integer
    attribute :change, :float do
      0.76
    end
    attribute :active, :boolean do
      true
    end
    extra_attribute :worth, :integer do
      100
    end
    attribute :salary, :integer, readable: :admin? do
      100_000
    end
    has_many :positions
    has_many :credit_cards
    many_to_many :teams, foreign_key: {employee_teams: :employee_id}
    polymorphic_has_many :notes, as: :notable

    attribute :guarded_first_name, :string, filterable: :admin?, sortable: :admin? do
      object.first_name
    end

    attribute :objekt, :hash do
      {foo: "bar"}
    end

    attribute :stringies, :array_of_strings do
      ["foo", "bar"]
    end

    attribute :ints, :array_of_integers do
      [1, 2]
    end

    attribute :floats, :array_of_floats do
      [0.01, 0.02]
    end

    attribute :datetimes, :array_of_datetimes do
      [Time.now, Time.now]
    end
    attribute :scalar_array, :array do
      [1, 2]
    end
    attribute :object_array, :array do
      [{foo: "bar"}, {baz: "bazoo"}]
    end

    filter :guarded_first_name do
      eq do |scope, value|
        scope[:conditions] ||= {}
        scope[:conditions][:first_name] = value
        scope
      end
    end

    sort :guarded_first_name do |scope, dir|
      scope[:sort] = [{first_name: dir}]
      scope
    end

    def admin?
      context[:current_user] == "admin"
    end
  end

  class PositionResource < ApplicationResource
    attribute :employee_id, :integer, only: [:filterable]
    attribute :active, :boolean
    attribute :title, :string
    attribute :rank, :integer
    extra_attribute :score, :integer do
      200
    end
    belongs_to :department
    belongs_to :employee
  end

  class ClassificationResource < ApplicationResource
  end

  class DepartmentResource < ApplicationResource
    attribute :name, :string
    has_many :teams
  end

  class NoteEditResource < ApplicationResource
    filter :note_id, :integer
    attribute :modification, :string
  end

  class NoteResource < ApplicationResource
    attribute :body, :string
    filter :notable_id, :integer
    filter :notable_type, :string

    has_many :edits, resource: PORO::NoteEditResource
  end

  class BioResource < ApplicationResource
  end

  class CreditCardResource < ApplicationResource
    self.polymorphic = %w[PORO::VisaResource PORO::GoldVisaResource PORO::MastercardResource]

    def base_scope
      {type: [:visas, :gold_visas, :mastercards]}
    end

    attribute :number, :integer
    attribute :description, :string
    filter :employee_id, :integer

    has_many :transactions
  end

  class TransactionResource < ApplicationResource
    attribute :amount, :integer
    filter :credit_card_id, :integer
  end

  class VisaResource < CreditCardResource
    attribute :description, :string do
      "visa description"
    end
    attribute :visa_only_attr, :string do
      "visa only"
    end

    def base_scope
      {type: :visas}
    end

    has_many :visa_rewards
  end

  class GoldVisaResource < VisaResource
    self.graphql_name = "Goldies"
  end

  class MastercardResource < CreditCardResource
    attribute :description, :string do
      "mastercard description"
    end

    def base_scope
      {type: :mastercards}
    end

    has_many :mastercard_miles
  end

  class MastercardMileResource < CreditCardResource
    filter :mastercard_id, :integer
    attribute :amount, :integer do
      100
    end

    def base_scope
      {type: :mastercard_miles}
    end
  end

  class VisaRewardTransactionResource < ApplicationResource
    filter :reward_id, :integer
    attribute :amount, :integer

    def base_scope
      {type: :visa_reward_transactions}
    end
  end

  class VisaRewardResource < ApplicationResource
    filter :visa_id, :integer
    attribute :points, :integer

    def base_scope
      {type: :visa_rewards}
    end

    has_many :reward_transactions,
      resource: PORO::VisaRewardTransactionResource,
      foreign_key: :reward_id
  end

  class PaypalResource < ApplicationResource
    attribute :account_id, :integer

    def base_scope
      {type: :paypals}
    end
  end

  class ApplicationSerializer < Graphiti::Serializer
  end
end