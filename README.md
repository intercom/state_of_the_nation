# StateOfTheNation

State of the Nation is a Gem that makes modeling state that changes over time easy with ActiveRecord, allowing you to ensure that you to easily query the value at any point in time, as well as ensuring that your records don't overlap at any point.

Take for example modeling the history of elected officials in the United States government. You would want to allow multiple Senators to be considered active at any point in time, while ensuring that only one President is active. Modeling this with StateOfTheNation is easy like so:

```ruby
class Country < ActiveRecord::Base
  include StateOfTheNation
  has_many :presidents
  has_many :senators

  has_active :senators
  has_uniquely_active :president
end

class President < ActiveRecord::Base
  belongs_to :country
  considered_active.from(:entered_office_at).until(:left_office_at)
end

class Senator < ActiveRecord::Base
  belongs_to :country
  considered_active.from(:entered_office_at).until(:left_office_at)
end

```

With this collection of models we can easy record and query the list of elected officials at any point in time, and be confident that any new records that we create don't collide.

```ruby
country.active_president(Date.new(2015, 1, 1)) 
# => President(id: 1, name: "Barack Obama")

country.active_senators(Date.new(2015, 1, 1))
# => [
# Senator(id: 1, name: "Ron Wyden"),
# ...
# ]


```
## Installation

Add this line to your application's Gemfile:

```ruby
gem 'state_of_the_nation'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install state_of_the_nation

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/intercom/state_of_the_nation. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

