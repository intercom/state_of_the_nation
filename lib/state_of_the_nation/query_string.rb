module StateOfTheNation
  class QueryString
    def self.query_for(type, klass)
      database_appropriate_types(klass)[type] % { finish_key: klass.finish_key, start_key: klass.start_key }
    end

    def self.database_appropriate_types(klass)
      return {
        postgresql: {
          active_scope: "(%{finish_key} IS NULL OR %{finish_key} > ?::timestamp) AND %{start_key} <= ?::timestamp",
          less_than: "(%{start_key} < ?::timestamp)",
          greater_than_or_null: "(%{finish_key} > ?::timestamp) OR (%{finish_key} IS NULL)",
          start_and_finish_not_equal_and_not_null: "(%{start_key} != %{finish_key}) OR (%{start_key} IS NULL) OR (%{finish_key} IS NULL)",
        },
        mysql: {
          active_scope: "(%{finish_key} IS NULL OR %{finish_key} > ?) AND %{start_key} <= ?",
          less_than: "(%{start_key} < ?)",
          greater_than_or_null: "(%{finish_key} > ?) OR (%{finish_key} IS NULL)",
          start_and_finish_not_equal_and_not_null: "(%{start_key} != %{finish_key}) OR (%{start_key} IS NULL) OR (%{finish_key} IS NULL)"
        }
      }[appropriate_db_type(klass)]
    end

    def self.appropriate_db_type(klass)
      case klass.connection.adapter_name
      when /PostgreSQL/
        :postgresql
      else
        :mysql
      end
    end
  end
end
