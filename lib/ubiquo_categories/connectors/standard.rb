module UbiquoCategories
  module Connectors
    class Standard < Base
      

      module Category

        def self.included(klass)
          klass.send(:extend, ClassMethods)
          Standard.register_uhooks klass, ClassMethods
        end

        module ClassMethods

          # Returns a condition to return categories using their +identifiers+
          def uhook_category_identifier_condition identifiers
            ['categories.id IN (?)', identifiers]
          end

          # Applies any required extra scope to the filtered_search method
          def uhook_filtered_search filters
            []
          end
        end

      end

      module CategorySet

        def self.included(klass)
          klass.send(:include, InstanceMethods)
          Standard.register_uhooks klass, InstanceMethods
        end

        module InstanceMethods
          # Returns an identifier value for a given +category_name+ in this set
          def uhook_category_identifier_for_name category_name
            self.select_fittest(category_name).id rescue 0
          end
        end
      end

      module UbiquoCategoriesController
        def self.included(klass)
          klass.send(:include, InstanceMethods)
          klass.send(:helper, Helper)
          Standard.register_uhooks klass, InstanceMethods
        end

        module Helper
          # Returns a string with extra filters for categories
          def uhook_category_filters url_for_options
            ''
          end

          # Returns an array with any display information for extra categories filters
          def uhook_category_filters_info
            []
          end

          # Returns content to show in the sidebar when editing an category
          def uhook_edit_category_sidebar category
            ''
          end

          # Returns content to show in the sidebar when creating an category
          def uhook_new_category_sidebar category
            ''
          end

          # Returns the available actions links for a given category
          def uhook_category_index_actions category_set, category
            [
              link_to(t('ubiquo.edit'), [:edit, :ubiquo, category_set, category]),
              link_to(t('ubiquo.remove'), [:ubiquo, category_set, category], :confirm => t("ubiquo.category.index.confirm_removal"), :method => :delete)
            ]
          end

          # Returns any necessary extra code to be inserted in the category form
          def uhook_category_form form
            ''
          end
        end

        module InstanceMethods

          # Returns a hash with extra filters to apply
          def uhook_index_filters
            {}
          end

          # Returns a subject that will have applied the index filters
          # (e.g. a class, with maybe some scopes applied)
          def uhook_index_search_subject
            ::Category
          end

          # Initializes a new instance of category.
          def uhook_new_category
            ::Category.new
          end

          # Performs any required action on category when in show
          # Show action will not continue if this hook returns false
          def uhook_show_category category
            true
          end

          # Performs any required action on category when in edit
          # Edit action will not continue if this hook returns false
          def uhook_edit_category category
            true
          end

          # Creates a new instance of category.
          def uhook_create_category
            ::Category.new(params[:category])
          end

          # Destroys a category instance. returns a success boolean
          def uhook_destroy_category(category)
            category.destroy
          end
        end
      end

      module Migration
        
        def self.included(klass)
          klass.send(:extend, ClassMethods)
          Standard.register_uhooks klass, ClassMethods
        end
        
        module ClassMethods
          def uhook_create_categories_table
            create_table :categories do |t|
              yield t
            end
          end

          def uhook_create_category_relations_table
            create_table :category_relations do |t|
              yield t
            end
          end
        end
      end

      module ActiveRecord
        module Base

          def self.included(klass)
            klass.send(:extend, ClassMethods)
            Standard.register_uhooks klass, ClassMethods
          end

          module ClassMethods
            
            # Adds the +categories+ to the +set+ and returns the categories that 
            # will be effectively related to +object+
            def uhook_assign_to_set set, categories, object
              set.categories << categories
              categories = Array(categories).reject(&:blank?)
              categories.map{|c| set.select_fittest c}.uniq.compact
            end
          end

        end
      end

      module UbiquoHelpers
        def self.included(klass)
          klass.append_helper(Helper)
        end

        module Helper
          # Returns a the applicable categories for +set+
          def uhook_categories_for_set set
            set.categories
          end
        end
      end
      
    end
  end
end
