module UbiquoCategories
  module CategorySelector
    module Helper

      # Renders a category selector in a form
      #   key: CategorySet key (required)
      #   options(optional):
      #     type (checkbox, select, autocomplete)
      #     name (Used for selector title)
      #     autocomplete_style (tag, list)
      #   html_options(optional)
      def category_selector(object_name, key, options = {}, html_options = {})
        object = options[:object]
        key = key.to_s.pluralize
        categories = category_set(key).categories
        if object.class.is_translatable?
          categories = categories.locale(object.locale, :ALL)
        end
        selector_type = options[:type]
        categorize_size = object.class.categorize_options(key)[:size]
        selector_type ||= case categories.size
          when 0..6
            (categorize_size == :many || categorize_size > 1) ? :checkbox : :select
          else
            :autocomplete
        end
        output = content_tag(:fieldset) do
          content_tag(:legend, options[:name] || object.class.human_attribute_name(key)) + 
            send("category_#{selector_type}_selector",
                 object, object_name, key, categories, options)
        end
        output
      end
      
      protected
      
      def category_set(key)
        CategorySet.find_by_key(key) || raise(SetNotFoundError, "CategorySet with key '#{key}' not found")
      end
      
      def category_checkbox_selector(object, object_name, key, categories, options = {})
        output = content_tag(:ul, :class => 'check_list') do
          categories.map do |category|
            content_tag(:li) do
              check_box_tag("#{object_name}[#{key}][]", category.name, 
                            object.send(key).has_category?(category),
                            :id => "#{object_name}_#{key}_#{category.id}") +
                label_tag("#{object_name}_#{key}_#{category.id}", category)
            end
          end.join
        end
        output << hidden_field_tag("#{object_name}[#{key}][]", '')
        output << new_category_controls("checkbox", object_name, key)
        output
      end
      
      def category_select_selector(object, object_name, key, categories, options = {})
        categories_for_select = categories.collect { |cat| [cat.name, cat.name] }
        output = select_tag("#{object_name}[#{key}][]", 
                             options_for_select(categories_for_select,
                                                :selected => object.send(key).name),
                             { :id => "#{object_name}_#{key}_select" })
        output << new_category_controls("select", object_name, key)
        output
      end
      
      def category_autocomplete_selector(object, object_name, key, categories, options = {})
        category_set = CategorySet.find_by_key(key)
        url_params = { :category_set_id => category_set.id, :format => :js }
        autocomplete_options = { 
          :url => ubiquo_category_set_categories_path(url_params),
          :current_values => object.send(key).to_json(:only => [:id, :name]),
          :style => options[:autocomplete_style] || "tag"
        }
        js_code =<<-JS
          document.observe('dom:loaded', function() {
            var autocomplete = new AutoCompleteSelector(
              '#{autocomplete_options[:url]}',
              '#{object_name}',
              '#{key}',
              #{autocomplete_options[:current_values]},
              '#{autocomplete_options[:style]}'
            )
          });
        JS
        javascript_tag(js_code) +
          text_field_tag("#{object_name}[#{key}][]", "",
                         :id => "#{object_name}_#{key}_autocomplete")
      end
      
      def new_category_controls(type, object_name, key)
        content_tag(:div, :class => "new_category_controls") do
          link_to(t("ubiquo.category_selector.new_element"), '#', 
                  :id => "link_new__#{type}__#{object_name}__#{key}",
                  :class => "category_selector_new") +
          content_tag(:div, :class => "add_new_category", :style => "display:none") do
            text_field_tag("new_#{object_name}_#{key}", "", :id => "new_#{object_name}_#{key}") +
            link_to(t("ubiquo.category_selector.add_element"), "", :class => "add_new_category_link")
          end
        end
      end
    end
  end
end


# Helper method for form builders
module ActionView
  module Helpers
    class FormBuilder
      def category_selector(key, options = {}, html_options = {})
        options = options.merge(:object => @object)
        @template.category_selector(@object_name, key, options, html_options)
      end
    end
  end
end
