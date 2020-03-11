# -*- coding: utf-8 -*-
require "spec_helper"

describe StateOfTheNation do
  # for ActiveRecord models who…
  #
  # - can be considered "active" between a start time and an end time
  # - belong to another ActiveRecord model
  # - where only one should be "active" at any point in time for the
  #   parent model
  #
  # example: a country has many presidents, which are active between
  #          entered_office_at and left_office_at, but a country can never
  #          have more than one active president for any point in time
  #
  #          a country also has many senators, active in the same way, but
  #          where many can be active at once

  class President < ActiveRecord::Base
    include StateOfTheNation

    belongs_to :country

    considered_active.from(:entered_office_at).until(:left_office_at)
  end

  class Senator < ActiveRecord::Base
    include StateOfTheNation

    belongs_to :country

    considered_active.from(:entered_office_at).until(:left_office_at)
  end

  class Country < ActiveRecord::Base
    include StateOfTheNation

    has_many :presidents
    has_many :senators

    has_uniquely_active :president
    has_active :senators
  end

  before :all do
    m = ActiveRecord::Migration.new
    m.create_table :presidents do |t|
      t.datetime :entered_office_at
      t.datetime :left_office_at
      t.integer :country_id
      t.string :comment
    end

    m.create_table :senators do |t|
      t.datetime :entered_office_at
      t.datetime :left_office_at
      t.integer :country_id
    end
    m.create_table :countries
  end

  after :all do
    m = ActiveRecord::Migration.new
    m.drop_table :presidents
    m.drop_table :senators
    m.drop_table :countries
  end

  context "convenience specs" do
    # can be used in including classes to test implementation is correct
    context "parent class" do
      subject { Country.new }

      it { is_expected.to include_state_of_the_nation }
      it { is_expected.to have_uniquely_active(:president) }
      it { is_expected.to have_active(:senators) }
    end

    context "child class" do
      subject { President.new }

      it { is_expected.to include_state_of_the_nation }
      it { is_expected.to be_considered_active.from(:entered_office_at).until(:left_office_at) }
    end
  end

  let(:country) { Country.create! }
  subject { President.new }

  context ".considered_active" do
    it "sets the correct class state" do
      expect(subject.class.start_key).to eq(:entered_office_at)
      expect(subject.class.finish_key).to eq(:left_office_at)
      expect(subject.class.parent_association).to eq(:country)
    end
  end

  context ".validates_uniquely_active" do
    it "sets the correct class state" do
      expect(subject.class.prevent_multiple_active).to eq(true)
    end
  end

  context "validates finishes_after_starts" do
    let(:finish_after_start_error) { [ActiveRecord::RecordInvalid, "Validation failed: Left office at must be after Entered office at"] }

    it "prevents creation of a record with finish date after start" do
      expect {
        country.presidents.create!(entered_office_at: day(10), left_office_at: day(5))
      }.to raise_error(*finish_after_start_error)
    end

    it "prevents updating of a record to have finish date after start" do
      p = country.presidents.create!(entered_office_at: day(4), left_office_at: day(5))
      expect {
        p.update!(entered_office_at: day(6))
      }.to raise_error(*finish_after_start_error)
    end

    it "doesn’t fail if no finish date set" do
      expect {
        country.presidents.create!(entered_office_at: day(10))
      }.not_to raise_error
    end

    it "doesn’t fail if finish date is the same as start date" do
      expect {
        country.presidents.create!(entered_office_at: day(10), left_office_at: day(10))
      }.not_to raise_error
    end
  end

  context ".has_uniquely_active" do
    let!(:washington) { country.presidents.create!(entered_office_at: day(1), left_office_at: day(8)) }
    let!(:roosevelt) { country.presidents.create!(entered_office_at: day(10), left_office_at: day(15)) }
    let!(:nixon) { country.presidents.create!(entered_office_at: day(15), left_office_at: day(18)) }
    let!(:reagan) { country.presidents.create!(entered_office_at: day(18), left_office_at: day(40)) }
    let!(:obama) { country.presidents.create!(entered_office_at: day(40)) }

    it "defaults to now" do
      travel_to(day(16)) do
        expect(President.active).to eq [nixon]

        expect(nixon).to be_active
        expect(obama).not_to be_active
      end
    end


    it "works" do
      expect(President.active(day(6))).to eq [washington]
      expect(President.active(day(12))).to eq [roosevelt]

      expect(country.active_president(day(6))).to eq washington
      expect(country.active_president(day(12))).to  eq roosevelt

      expect(washington).to be_active(day(6))
      expect(obama).not_to be_active(day(6))

      expect(roosevelt).to be_active(day(12))
      expect(washington).not_to be_active(day(12))
    end

    it "works on the boundaries" do
      expect(President.active(day(15))).to eq [nixon]

      expect(country.active_president(day(15))).to eq nixon

      expect(nixon).to be_active(day(15))
      expect(roosevelt).not_to be_active(day(15))
    end

    it "works when nothing active" do
      expect(President.active(day(9))).to eq []

      expect(country.active_president(day(9))).to eq nil

      [washington, roosevelt, nixon, reagan, obama].each do |president|
        expect(president).not_to be_active(day(9))
      end
    end

    it "works when no finish date" do
      expect(President.active(day(45))).to eq [obama]

      expect(country.active_president(day(45))).to eq obama

      expect(obama).to be_active(day(45))
    end

    it "works before any active" do
      expect(President.active(day(0.5))).to eq []

      expect(country.active_president(day(0.5))).to eq nil

      [washington, roosevelt, nixon, reagan, obama].each do |president|
        expect(president).not_to be_active(day(0.5))
      end
    end
  end

  context ".has_active" do
    let!(:byrd) { country.senators.create!(entered_office_at: day(1959), left_office_at: day(2010)) }
    let!(:inouye) { country.senators.create!(entered_office_at: day(1963), left_office_at: day(2012)) }
    let!(:thurmond) { country.senators.create!(entered_office_at: day(1954), left_office_at: day(2003)) }
    let!(:kennedy) { country.senators.create!(entered_office_at: day(1962), left_office_at: day(2009)) }
    let!(:cochran) { country.senators.create!(entered_office_at: day(1978)) }

    it "defaults to now" do
      travel_to(day(1960)) do
        expect(Senator.active).to eq [byrd, thurmond]

        expect(byrd).to be_active
        expect(kennedy).not_to be_active
      end
    end

    it "works" do
      expect(Senator.active(day(2008))).to eq [byrd, inouye, kennedy, cochran]

      expect(country.active_senators(day(2008))).to eq [byrd, inouye, kennedy, cochran]

      expect(byrd).to be_active(day(2008))
      expect(thurmond).not_to be_active(day(2008))
    end

    it "works on the boundaries" do
      expect(Senator.active(day(1954))).to include thurmond
      expect(Senator.active(day(2003))).not_to include thurmond

      expect(country.active_senators(day(1954))).to include thurmond
      expect(country.active_senators(day(2003))).not_to include thurmond

      expect(thurmond).to be_active(day(1954))
      expect(thurmond).not_to be_active(day(2003))
    end

    it "works when nothing active" do
      expect(Senator.active(day(1600))).to eq []

      expect(country.active_senators(day(1600))).to eq []

      [byrd, inouye, thurmond, kennedy, cochran].each do |senator|
        expect(senator).not_to be_active(day(1600))
      end
    end
  end

  context ".active_in_period" do
    let(:unbounded_president) { country.presidents.create!(entered_office_at: day(4), left_office_at: nil) }
    let(:bounded_president) { country.presidents.create!(entered_office_at: day(1), left_office_at: day(4)) }
    let(:president_with_empty_active_period) { country.presidents.create!(entered_office_at: day(4), left_office_at: day(4)) }

    it "returns true for records that are active in the interval" do
      expect(bounded_president).to be_active_in_interval(interval_start: day(3), interval_end: day(7))
      expect(bounded_president).to be_active_in_interval(interval_start: day(3), interval_end: nil)
      expect(bounded_president).to be_active_in_interval(interval_start: nil, interval_end: day(3))
      expect(bounded_president).to be_active_in_interval(interval_start: nil, interval_end: nil)

      expect(unbounded_president).to be_active_in_interval(interval_start: day(4), interval_end: day(12))
      expect(unbounded_president).to be_active_in_interval(interval_start: day(4), interval_end: nil)
      expect(unbounded_president).to be_active_in_interval(interval_start: nil, interval_end: day(12))
      expect(unbounded_president).to be_active_in_interval(interval_start: nil, interval_end: nil)
    end

    it "returns true for records with an empty activation period in the range" do
      expect(president_with_empty_active_period).to be_active_in_interval(interval_start: day(3), interval_end: day(5))
      expect(president_with_empty_active_period).to be_active_in_interval(interval_start: day(3), interval_end: nil)
      expect(president_with_empty_active_period).to be_active_in_interval(interval_start: nil, interval_end: day(5))
      expect(president_with_empty_active_period).to be_active_in_interval(interval_start: nil, interval_end: nil)
    end

    it "returns false for records active outside the range" do
      expect(bounded_president).not_to be_active_in_interval(interval_start: day(4), interval_end: day(7))
      expect(bounded_president).not_to be_active_in_interval(interval_start: day(4), interval_end: nil)

      expect(unbounded_president).not_to be_active_in_interval(interval_start: day(2), interval_end: day(4))
      expect(unbounded_president).not_to be_active_in_interval(interval_start: nil, interval_end: day(4))

      expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: day(4), interval_end: day(6))
      expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: day(4), interval_end: nil)
      expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start:  nil, interval_end: day(4))
    end

    context "for records without a start date set" do
      before do
        travel_to(day(30))
      end

      let(:open_started_president) { country.presidents.create!(entered_office_at: nil, left_office_at: day(60)) }

      it "deems them to be active from now" do
        expect(open_started_president).not_to be_active_in_interval(interval_start: day(25), interval_end: day(30))
        expect(open_started_president).to be_active_in_interval(interval_start: day(30), interval_end: day(35))
      end

    end

    context "with ignore_empty as true" do
      before do
        allow(President).to receive(:ignore_empty).and_return(true)
      end

      it "returns true for records that are active in the interval" do
        expect(bounded_president).to be_active_in_interval(interval_start: day(3), interval_end: day(7))
        expect(bounded_president).to be_active_in_interval(interval_start: day(3), interval_end: nil)
        expect(bounded_president).to be_active_in_interval(interval_start: nil, interval_end: day(3))
        expect(bounded_president).to be_active_in_interval(interval_start: nil, interval_end: nil)

        expect(unbounded_president).to be_active_in_interval(interval_start: day(4), interval_end: day(12))
        expect(unbounded_president).to be_active_in_interval(interval_start: day(4), interval_end: nil)
        expect(unbounded_president).to be_active_in_interval(interval_start: nil, interval_end: day(12))
        expect(unbounded_president).to be_active_in_interval(interval_start: nil, interval_end: nil)
      end

      it "returns false for records with an empty activation period in the range" do
        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: day(3), interval_end: day(5))
        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: day(3), interval_end: nil)
        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: nil, interval_end: day(5))
        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: nil, interval_end: nil)
      end

      it "returns false for records active outside the range" do
        expect(bounded_president).not_to be_active_in_interval(interval_start: day(4), interval_end: day(7))
        expect(bounded_president).not_to be_active_in_interval(interval_start: day(4), interval_end: nil)

        expect(unbounded_president).not_to be_active_in_interval(interval_start: day(2), interval_end: day(4))
        expect(unbounded_president).not_to be_active_in_interval(interval_start: nil, interval_end: day(4))

        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: day(4), interval_end: day(6))
        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start: day(4), interval_end: nil)
        expect(president_with_empty_active_period).not_to be_active_in_interval(interval_start:  nil, interval_end: day(4))
      end

    end
  end

  context "before_validation: prevent_active_collisions" do
    let(:pres1) { country.presidents.create!(entered_office_at: day(1), left_office_at: day(10)) }
    let(:pres2) { country.presidents.create!(entered_office_at: day(5), left_office_at: day(12)) }
    let(:pres3) { country.presidents.create!(entered_office_at: day(10), left_office_at: day(12)) }
    let(:pres4) { country.presidents.create!(entered_office_at: day(15), left_office_at: day(22)) }
    let(:pres5) { President.create!(entered_office_at: pres1.entered_office_at, left_office_at: pres1.left_office_at) }
    let(:pres6) { country.presidents.create!(entered_office_at: day(5), left_office_at: day(5)) }
    let(:pres7) { country.presidents.create!(entered_office_at: day(6), left_office_at: nil)}


    it "raises an exception if multiple active would have occurred from creation" do
      expect { pres1; pres2 }.to raise_error StateOfTheNation::ConflictError
    end

    it "raises an exception if multiple active would have occurred from updating" do
      expect {
        pres1
        pres3.update!(entered_office_at: day(9))
      }.to raise_error StateOfTheNation::ConflictError
    end

    it "does nothing if it’s not associated to scoped model yet" do
      expect { pres1; pres5 }.not_to raise_error
    end

    it "raises an exception if existing model has an empty activation interval" do
      expect { pres6; pres1 }.to raise_error StateOfTheNation::ConflictError
    end

    it "does nothing if existing model has an empty activation interval and empty intervals are ignored" do
      allow(President).to receive(:ignore_empty).and_return(true)

      expect { pres6; pres1 }.not_to raise_error
    end

    it "unterminated existing model are considered active" do
      expect { pres7; pres1 }.to raise_error StateOfTheNation::ConflictError
    end

    it "unterminated existing model are considered active when empty intervals are ignored" do
      allow(President).to receive(:ignore_empty).and_return(true)

      expect { pres7; pres1 }.to raise_error StateOfTheNation::ConflictError
    end

    it "does nothing if prevent_multiple_active is set to false" do
      allow(President).to receive(:prevent_multiple_active).and_return(false)

      expect { pres1; pres2 }.not_to raise_error
    end

    it "is OK with multiple if only one active" do
      expect { pres1; pres3; pres4 }.not_to raise_error
    end

    it "doesn’t prevent saving an already active record" do
      travel_to(day(11)) do
        expect { pres3.update!(left_office_at: day(14)) }.not_to raise_error
      end
    end

    it "assumes start key value of now if blank" do
      # protects against created_at being unset for a new record

      expect { pres3; pres4.update!(comment: "yo") }.not_to raise_error

      allow(pres4).to receive(:entered_office_at).and_return(nil)

      travel_to(pres3.entered_office_at) do
        expect {
          pres3; pres4.update!(comment: "no")
        }.to raise_error StateOfTheNation::ConflictError
      end
    end

    context "configuration issues" do
      [:start_key, :finish_key].each do |variable_name|
        it "raises an exception if #{variable_name} is not set" do
          allow(President).to receive(variable_name).and_return(nil)

          expect { pres1 }.to raise_error StateOfTheNation::ConfigurationError
        end
      end
    end
  end

  context "#should_round_timestamps?" do
    let(:country) { Country.create }
    let!(:washington) { country.presidents.create!(entered_office_at: day(1), left_office_at: day(8)) }
    let(:sub_second_timestamp) { 1270643035.04671 }
    let(:sub_second_time) { Time.at(sub_second_timestamp)  }

    it "is true for MySQL" do
      allow(President).to receive_message_chain(:connection, :adapter_name).
        and_return("MySQL")
      expect(washington.send(:should_round_timestamps?)).to eq(true)
    end

    it "is false for PostgreSQL" do
      allow(President).to receive_message_chain(:connection, :adapter_name).
                           and_return("PostgreSQL")
      expect(washington.send(:should_round_timestamps?)).to eq(false)
    end

    it "is true for SQLite" do
      allow(President).to receive_message_chain(:connection, :adapter_name).
                           and_return("SQLite")
      expect(washington.send(:should_round_timestamps?)).to eq(true)
    end
  end

  context "IdentityCache support" do
    before do
      class Country < ActiveRecord::Base
        include StateOfTheNation

        has_many :presidents

        has_uniquely_active(:president).with_identity_cache
      end
    end
    after do
      class Country < ActiveRecord::Base
        include StateOfTheNation

        has_many :presidents
        has_many :senators

        has_uniquely_active(:president)
        has_active(:senators)
      end
    end

    let(:country) { Country.create }
    let!(:president) { country.presidents.create!(entered_office_at: day(1), left_office_at: day(8)) }

    context ".using_identity_cache" do
      it "uses the fetch_method to retrieve records" do
        expect(country).to receive(:fetch_presidents)
          .and_return([president])
        expect(country.active_president(day(7))).to eq(president)
      end
    end
  end

  context "creating records with non-Time values" do
    let(:country) { Country.create }
    it "works" do
      washington = country.presidents.create!(
        entered_office_at: Date.new(1789, 4, 30),
        left_office_at: Date.new(1797, 5, 4)
      )
      expect(country.active_president(Date.new(1790, 1, 1))).to eq(washington)
    end
  end
end
