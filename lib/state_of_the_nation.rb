require "state_of_the_nation/errors/conflict_error"
require "state_of_the_nation/errors/configuration_error"
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
    attr_accessor :prevent_multiple_active, :parent_association, :start_key, :finish_key, :ignore_empty

    def considered_active(ignore_empty: false)
      @ignore_empty = ignore_empty

      def from(start_key)
        @start_key = start_key
        self
      end

      def until(finish_key)
        @finish_key = finish_key

        define_method "active?" do |time = Time.now.utc|
          (finish.blank? || finish > time) && start <= time
        end

        define_method "active_in_interval?" do |interval_start, interval_end|
          record_start = start
          record_end = finish
          if ignore_empty && record_start == record_end
            false
          elsif interval_start.nil? && interval_end.nil?
            true
          elsif interval_start == interval_end
            active?(interval_start)
          elsif interval_start.nil?
            record_start < interval_end
          elsif interval_end.nil?
            record_end.nil? || record_end > interval_start
          elsif record_end.nil?
            interval_end > record_start
          else
            record_start < interval_end && record_end > interval_start
          end
        end

        scope :active, lambda { |time = Time.now.utc|
          where(QueryString.query_for(:active_scope, self), time, time)
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
      reflection = self.reflect_on_association(plural)
      name = reflection.inverse_of&.name || self.name.demodulize.underscore.to_sym

      child_class = reflection.klass
      child_class.instance_variable_set(:@parent_association, name)
      child_class.instance_variable_set(:@prevent_multiple_active, single)

      association = single ? plural.singularize : plural

      define_method "active_#{association}" do |time = Time.now.utc|
        method_name = with_identity_cache ? "fetch_#{plural}" : plural.to_sym
        collection = send(method_name).select { |r| r.send("active?", time) }
        single ? collection.first : collection
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
    raise ConfigurationError if bad_configuration?
    return unless model.present?

    raise ConflictError.new(self, other_records_active_in_range) if other_records_active_in_range.any?
  end

  def other_records_active_in_range
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

    records = records.where(QueryString.query_for(:start_and_finish_not_equal_or_are_null, self.class)) if ignore_empty
    # exclude records where there is no difference between start and finish dates
    # (we need to deliberately not filter out records with null value keys with this comparison as not equal comparisons to null are always deemed null/false)

    records
  end

  def model
    return unless parent_association.present?
    self.send(parent_association)
  end

  def start
    return unless start_key.present?
    return self.send(start_key) || Time.now.utc
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

  def ignore_empty
    self.class.ignore_empty
  end
end
