require "state_of_the_nation/errors"
require "state_of_the_nation/version"
require "state_of_the_nation/query_string"
require "active_support/all"

module StateOfTheNation
  extend ActiveSupport::Concern

  included do
    before_validation :prevent_active_collisions
    before_validation :ensure_finishes_after_starts
  end

  module ClassMethods
    attr_accessor :prevent_multiple_active, :parent_association, :start_key, :finish_key

    def considered_active
      def from(start_key)
        @start_key = start_key
        self
      end

      def until(finish_key)
        @finish_key = finish_key

        define_method "active?" do |time = Time.now.utc|
          time = should_round_timestamps? ? time.round : time
          (finish.blank? || finish > time) && start <= time
        end

        scope :active, lambda { |t = Time.now.utc|
          where(QueryString.query_for(:active_scope, self), t, t)
        }
      end

      self
    end

    def has_active(association_plural)
      @association_plural = association_plural
      add_child_methods(plural: @association_plural, single: false, with_identity_cache: false)

      def with_identity_cache
        add_child_methods(plural: @association_plural, single: false, with_identity_cache: true)
        self
      end

      self
    end

    def has_uniquely_active(association_singular)
      @association_plural = association_singular.to_s.pluralize
      add_child_methods(plural: @association_plural, single: true, with_identity_cache: false)

      def with_identity_cache
        add_child_methods(plural: @association_plural, single: true, with_identity_cache: true)
        self
      end

      self
    end

    private

    def add_child_methods(plural:, single:, with_identity_cache:)
      child_class = self.reflect_on_association(plural).klass
      name = self.name.demodulize.underscore.to_sym
      child_class.instance_variable_set(:@parent_association, name)
      child_class.instance_variable_set(:@prevent_multiple_active, single)

      association = single ? plural.singularize : plural

      define_method "active_#{association}" do |time = Time.now.utc|
        time = should_round_timestamps? ? time.round : time
        method_name = with_identity_cache ? "fetch_#{plural}" : plural.to_sym
        collection = send(method_name).select { |r| r.send("active?", time) }
        single ? collection.first : collection
      end
    end

    def should_round_timestamps?
      # MySQL datetime fields do not support millisecond resolution while
      # PostgreSQL's do. To prevent issues with near identical timestamps not
      # comparing as expected in .active? methods we'll choose the resolution
      # appropriate for the database adapter backing the model.
      case self.connection.adapter_name
      when /PostgreSQL/
        false
      else
        true
      end
    end
  end

  private

  def ensure_finishes_after_starts
    return if finish.blank?
    return if finish >= start
    errors.add(finish_key, "must be after #{start_key.to_s.humanize}")
  end

  def prevent_active_collisions
    return unless prevent_multiple_active
    raise ConfigurationError.new if bad_configuration?
    return unless model.present?

    raise ConflictError.new if other_record_active_in_range?
  end

  def other_record_active_in_range?
    records = self.class.where(parent_association => model)
    # all records scoped to the model (e.g. all subscriptions for a customer)

    records = records.where("id != ?", id) if id.present?
    # excluding the current record

    records = records.where(QueryString.query_for(:less_than, self.class), finish) if finish.present?
    # find competing records which *start* being active BEFORE the current record *finishes* being active
    # (if the current record is set to finish being active)

    records = records.where(QueryString.query_for(:greater_than_or_null, self.class), start)
    # find competing records which *finish* being active AFTER this record *starts* being active
    # (or ones which are not set to finish being active)

    records.any?
  end

  def model
    return unless parent_association.present?
    self.send(parent_association)
  end

  def start
    return unless start_key.present?
    self.send(start_key) || Time.now.utc
  end

  def finish
    return unless finish_key.present?
    self.send(finish_key)
  end

  def bad_configuration?
    [start_key, finish_key].any?(&:blank?)
  end

  private

  def prevent_multiple_active
    self.class.prevent_multiple_active
  end

  def parent_association
    self.class.parent_association
  end

  def start_key
    self.class.start_key
  end

  def finish_key
    self.class.finish_key
  end

  def should_round_timestamps?
    self.class.send(:should_round_timestamps?)
  end
end
