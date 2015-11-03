require "cases/helper"
require 'models/post'
require 'models/comment'

module ActiveRecord
  module ConnectionAdapters
    class Mysql2SchemaTest < ActiveRecord::Mysql2TestCase
      fixtures :posts

      def setup
        @connection = ActiveRecord::Base.connection
        db          = Post.connection_pool.spec.config[:database]
        table       = Post.table_name
        @db_name    = db

        @omgpost = Class.new(ActiveRecord::Base) do
          self.inheritance_column = :disabled
          self.table_name = "#{db}.#{table}"
          def self.name; 'Post'; end
        end
      end

      class MysqlDouble < ActiveRecord::Base
        self.table_name = "mysql_doubles"
      end

      def test_float_limits
        @connection.create_table :mysql_doubles do |t|
          t.float :float_no_limit
          t.float :float_short, limit: 5
          t.float :float_long, limit: 53

          t.float :float_23, limit: 23
          t.float :float_24, limit: 24
          t.float :float_25, limit: 25
        end

        MysqlDouble.reset_column_information

        column_no_limit = MysqlDouble.columns.find { |c| c.name == 'float_no_limit' }
        column_short = MysqlDouble.columns.find { |c| c.name == 'float_short' }
        column_long = MysqlDouble.columns.find { |c| c.name == 'float_long' }

        column_23 = MysqlDouble.columns.find { |c| c.name == 'float_23' }
        column_24 = MysqlDouble.columns.find { |c| c.name == 'float_24' }
        column_25 = MysqlDouble.columns.find { |c| c.name == 'float_25' }

        # Mysql floats are precision 0..24, Mysql doubles are precision 25..53
        assert_equal 24, column_no_limit.limit
        assert_equal 24, column_short.limit
        assert_equal 53, column_long.limit

        assert_equal 24, column_23.limit
        assert_equal 24, column_24.limit
        assert_equal 53, column_25.limit
      ensure
        @connection.drop_table "mysql_doubles", if_exists: true
      end

      def test_schema
        assert @omgpost.first
      end

      def test_primary_key
        assert_equal 'id', @omgpost.primary_key
      end

      def test_table_exists?
        name = @omgpost.table_name
        assert @connection.table_exists?(name), "#{name} table should exist"
      end

      def test_table_exists_wrong_schema
        assert(!@connection.table_exists?("#{@db_name}.zomg"), "table should not exist")
      end

      def test_dump_indexes
        index_a_name = 'index_key_tests_on_snack'
        index_b_name = 'index_key_tests_on_pizza'
        index_c_name = 'index_key_tests_on_awesome'

        table = 'key_tests'

        indexes = @connection.indexes(table).sort_by(&:name)
        assert_equal 3,indexes.size

        index_a = indexes.select{|i| i.name == index_a_name}[0]
        index_b = indexes.select{|i| i.name == index_b_name}[0]
        index_c = indexes.select{|i| i.name == index_c_name}[0]
        assert_equal :btree, index_a.using
        assert_nil index_a.type
        assert_equal :btree, index_b.using
        assert_nil index_b.type

        assert_nil index_c.using
        assert_equal :fulltext, index_c.type
      end

      unless mysql_enforcing_gtid_consistency?
        def test_drop_temporary_table
          @connection.transaction do
            @connection.create_table(:temp_table, temporary: true)
            # if it doesn't properly say DROP TEMPORARY TABLE, the transaction commit
            # will complain that no transaction is active
            @connection.drop_table(:temp_table, temporary: true)
          end
        end
      end
    end
  end
end
