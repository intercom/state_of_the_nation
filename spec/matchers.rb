RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end

RSpec::Matchers.define :include_state_of_the_nation do
  match do |subject|
    subject.class.ancestors.include?(StateOfTheNation)
  end
end

RSpec::Matchers.define :include_identity_cache do
  match do |subject|
    subject.class.ancestors.include?(IdentityCache)
  end
end

RSpec::Matchers.define :be_considered_active do
  chain(:from) { |key| @start_key = key }
  chain(:until) { |key| @finish_key = key }
  match do |subject|
    subject.class.start_key == @start_key &&
    subject.class.finish_key == @finish_key
  end
end

RSpec::Matchers.define :have_uniquely_active do |association_singular|
  match do |subject|
    subject.respond_to?("active_#{association_singular}")
  end
end

RSpec::Matchers.define :have_active do |association_plural|
  match do |subject|
    subject.respond_to?("active_#{association_plural}")
  end
end
