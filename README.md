# StateOfTheNation

[![Build Status](https://travis-ci.com/intercom/state_of_the_nation.svg?token=Z1aavhs79p7e6XpUgjv5&branch=master)](https://travis-ci.com/intercom/state_of_the_nation)

StateOfTheNation makes modeling state that changes over time easy with ActiveRecord, allowing you to query the active value at any point in time, as well as ensure that your records don't overlap at any point.

Take for example modeling the history of elected officials in the United States Government where multiple Senators and only one President may be "active" for any point in time. Modeling this with StateOfTheNation is easy like so:

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
obama = usa.presidents.create!(entered_office_at: Date.new(2009, 1, 20), left_office_at: nil)

wyden = usa.senators.create!(entered_office_at: Date.new(1996, 2, 6), left_office_at: nil, name: "Ron Wyden")
boxer = usa.senators.create!(entered_office_at: Date.new(1993, 1, 3), left_office_at: nil, name: "Barbara Boxer")

usa.active_president(Date.new(2015, 1, 1)) 

# => President(id: 1, name: "Barack Obama")

usa.active_senators(Date.new(2015, 1, 1))
# => [
# Senator(id: 1, name: "Ron Wyden"),
# Senator(id: 2, name: "Barbara Boxer")
# ...
# ]


```
## IdentityCache Support

StateOfTheNation optionally supports fetching child records out of an IdentityCache cache instead of reading directly from the SQL table. 

For example if the Country model uses IdentityCache to cache the has_many relationship to President, you can make StateOfTheNation use the IdentityCache methods by calling `.with_identity_cache` on your `has_active` or `has_uniquely_active` definitions like so.

```ruby
class Country
  include IdentityCache
  include StateOfTheNation
  
  has_many(:presidents)
  cache_has_many(:presidents)
  has_uniquely_active(:president).with_identity_cache
end
```

Now every time the `Country#active_president` method is called StateOfTheNation will read through the IdentityCache methods and avoid a SELECT operation if possible.

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

