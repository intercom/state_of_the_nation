# StateOfTheNation

[![Build Status](https://travis-ci.org/intercom/state_of_the_nation.svg?branch=master)](https://travis-ci.org/intercom/state_of_the_nation)

StateOfTheNation helps model data whose _active_ state changes over time. It provides out-of-the-box query methods to locate the record or records active at any moment. Optionally, it also enforces _uniquely_ active constraints at the application level – ensuring that only one record in a collection is active at once.

## Example

Take elected officials in the US Government: multiple Senators are in office (i.e. active) at any point in time, but there's only one President.

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

usa = Country.create(name: "United States of America")
obama = usa.presidents.create!(name: "Barack Obama", entered_office_at: Date.new(2009, 1, 20))

usa.senators.create!(name: "Ron Wyden", entered_office_at: Date.new(1996, 2, 6))
usa.senators.create!(name: "Barbara Boxer", entered_office_at: Date.new(1993, 1, 3))
usa.senators.create!(name: "Alan Cranston", entered_office_at: Date.new(1969, 1, 3), left_office_at: Date.new(1993, 1, 3))

usa.active_president(Date.new(2015)) 
# => President(id: 1, name: "Barack Obama", …)

obama.active?
#=> true

usa.active_senators(Date.new(2015))
# => [Senator(id: 1, name: "Ron Wyden", …), Senator(id: 2, name: "Barbara Boxer", …)]

usa.presidents.create!(name: "Mitt Romney", entered_office_at: Date.new(2013, 1, 20))
# => StateOfTheNation::ConflictError
```
## IdentityCache Support

StateOfTheNation optionally supports fetching records through [IdentityCache](https://github.com/Shopify/identity_cache)  instead of reading directly from the database. 

For example if the `Country` model uses IdentityCache to cache the `has_many` relationship to `President`, you can instruct StateOfTheNation to fetch from the cache by calling `.with_identity_cache` on your `has_active` or `has_uniquely_active` definitions:

```ruby
class Country
  include IdentityCache
  include StateOfTheNation
  
  has_many(:presidents)
  cache_has_many(:presidents)
  has_uniquely_active(:president).with_identity_cache
end
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

Bug reports and pull requests are welcome on GitHub at https://github.com/intercom/state_of_the_nation. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org/) code of conduct.

test
