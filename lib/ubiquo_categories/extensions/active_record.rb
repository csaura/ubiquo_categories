module UbiquoCategories
  module Extensions
    module ActiveRecord

      def self.append_features(base)
        super
        base.extend(ClassMethods)
      end
      
      module ClassMethods

        DEFAULT_CATEGORIZED_OPTIONS = {
          :size => 1,
          :separator => '##'
        }

        # Class method for ActiveRecord that states that a attribute is categorized
        #
        # Example:
        #
        #   categorized_with :city
        # 
        # possible options:
        #   :from => CategorySet key(s) where this attribute should feed from.
        #            If it's not provided, will pluralize the attribute name and
        #            use it as the key.
        #   :size => the max number of categories that can be selected.
        #            Can be an integer or :many if there is no limit. Default: 1
        #   :separator => The char(s) that delimite the different categories when
        #                 creating them from a string. Defaults to double hash (##)
        #
        #

        def categorized_with(field, options = {})
          options.reverse_merge!(DEFAULT_CATEGORIZED_OPTIONS)
          
          self.has_many(:category_relations, {
              :as => :related_object,
              :class_name => "::CategoryRelation",
              :dependent => :destroy,
              :order => "category_relations.position ASC"
          }) unless self.respond_to?(:category_relations)

          association_name = field.to_s.pluralize
          set_key = (options[:from] || association_name).to_s

          @categorized_with_options ||= {}
          @categorized_with_options[association_name.to_sym] = options

          assign_to_set = Proc.new do |categories, object|
            set = CategorySet.find_by_key set_key
            raise UbiquoCategories::SetNotFoundError unless set

            categories = uhook_assign_to_set set, categories, object
            [set, categories]
          end

          proc = Proc.new do

            define_method "<<" do |categories|
              set, categories = assign_to_set.call(categories, proxy_owner)
              
              categories.each do |category|
                unless has_category? category.to_s
                  raise UbiquoCategories::LimitError if is_full?
                  @reflection.through_reflection.klass.create(
                    :attr_name => association_name,
                    :related_object => proxy_owner,
                    :category => category
                  )
                end
              end
              reset
            end

            if options[:size] == 1
              # Returns directly the instance if only one category is allowed
              def method_missing(method, *args)
                if load_target
                  if @target.first.respond_to?(method)
                    if block_given?
                      @target.first.send(method, *args)  { |*block_args| yield(*block_args) }
                    else
                      @target.first.send(method, *args)
                    end
                  else
                    super
                  end
                end
              end
            end
            
            define_method 'is_full?' do
              return false if options[:size].to_sym == :many
              Array(self).size >= options[:size]
            end

            define_method 'will_be_full?' do |categories|
              return false if options[:size].to_sym == :many
              categories.size > options[:size]
            end

            define_method 'has_category?' do |category|
              Array(self).map(&:to_s).include? category.to_s
            end

            # Automatically set the required attr_name when creating through the through
            define_method 'construct_owner_attributes' do |reflection|
              super.merge(:attr_name => association_name.to_s)
            end

          end

          self.has_many(association_name.to_sym, {
              :through => :category_relations,
              :class_name => "::Category",
              :source => :category,
              :conditions => ["category_relations.attr_name = ?", association_name],
              :order => "category_relations.position ASC",
            },&proc)
          
          define_method "#{association_name}_with_categories=" do |categories|
            categories = categories.split(options[:separator]) if categories.is_a? String

            set, categories = assign_to_set.call(categories, self)

            raise UbiquoCategories::LimitError if send(association_name).will_be_full? categories

            CategoryRelation.send(:with_scope, :create => {:attr_name => association_name}) do
              self.send("#{association_name}_without_categories=", categories)
            end

          end
          
          alias_method_chain "#{association_name}=", 'categories'

          named_scope "with_#{association_name}_in", lambda{ |*values|
            category_conditions_for field, values
          }

          if field != association_name
            alias_method field, association_name
            alias_method "#{field}=", "#{association_name}="
            klass = class << self; self; end
            klass.send :alias_method,  "with_#{field}_in", "with_#{association_name}_in"
          end

          prepare_categories_join_sql field

          uhook_categorized_with field, options
          
        end

        def categorized_with_options_lookup
          return {} if self.name == ::ActiveRecord::Base.name 
          @categorized_with_options = {} if @categorized_with_options.blank?
          return @categorized_with_options.reverse_merge(self.superclass.categorized_with_options_lookup)
        end
        
        # Returns the associated options for the categorized +field+
        def categorize_options(field)
          categorized_with_options = self.categorized_with_options_lookup
          raise UbiquoCategories::CategorizationNotFoundError if categorized_with_options.blank?
          association_name = field.to_s.pluralize.to_sym
          categorized_with_options[association_name]
        end

        def category_conditions_for field, category_names
          association_name = field.to_s.pluralize.to_sym

          options = categorize_options(association_name)
          raise UbiquoCategories::CategorizationNotFoundError unless options

          set = CategorySet.find_by_key "#{options[:from] || association_name}"
          raise UbiquoCategories::SetNotFoundError unless set

          value = Array(category_names).map do |category_name|
            value = set.uhook_category_identifier_for_name category_name
          end.compact

          value = [0] if value.blank? # to prevent rails sql bad formation

          {
            :conditions => Category.uhook_category_identifier_condition(value, association_name),
            :joins => categorize_options(field)[:join_sql]
          }
        end

        protected

        def prepare_categories_join_sql field
          association_name = field.to_s.pluralize.to_s

          relation_table = connection.quote_table_name(CategoryRelation.table_name)
          category_table = connection.quote_table_name(Category.table_name)
          relation_alias = connection.quote_table_name(CategoryRelation.alias_for_association(association_name))
          category_alias = connection.quote_table_name(Category.alias_for_association(association_name))

          categorize_options(field)[:join_sql] = <<-SQL
            INNER JOIN #{relation_table} #{relation_alias} ON
            (#{table_name}.id = #{relation_alias}.related_object_id AND
            #{relation_alias}.related_object_type = #{quote_value(base_class.name)})
            INNER JOIN #{category_table} #{category_alias} ON
            (#{category_alias}.id = #{relation_alias}.category_id) AND
            #{relation_alias}.attr_name = #{quote_value(association_name)}
          SQL
        end

      end

    end
  end
end
