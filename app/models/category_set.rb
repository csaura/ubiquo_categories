class CategorySet < ActiveRecord::Base

  has_many :categories do
    def << categories
      if categories.is_a? Array
        options = categories.extract_options!
      else
        categories = [categories]
        options = {}
      end
      categories.flatten.each do |category|
        # skip if already added
        load_target
        next if proxy_target.map(&:to_s).include? category.to_s
          
        case category
        when String
          raise UbiquoCategories::CreationNotAllowed unless proxy_owner.is_editable?
          self.concat(Category.new(:name => category, :locale => (options[:locale] || :any).to_s))
        else
          self.concat(category)
        end
      end
    end
  end

  validates_presence_of :name

  def initialize(attrs = {})
    attrs ||= {}
    attrs.reverse_merge!(:is_editable => true)
    super attrs
  end



  # See vendor/plugins/ubiquo_core/lib/ubiquo/extensions/active_record.rb to see an example of usage.
  def self.filtered_search(filters = {}, options = {})
    
    scopes = create_scopes(filters) do |filter, value|
      case filter
      when :text
        {:conditions => ["upper(category_sets.name) LIKE upper(?)", "%#{value}%"]}
      end
    end
    
    apply_find_scopes(scopes) do
      find(:all, options)
    end
  end

  # sets the set as editable
  def is_editable!
    update_attribute :is_editable, true
  end

  # sets the set as not editable
  def is_not_editable!
    update_attribute :is_editable, false
  end

  # Returns the fittest category given the required params
  #   category: either a Category or a string (category name)
  #   locale: expected locale of the category
  def select_fittest(category, locale = nil)
    case category
    when Category
      if locale
        category.locale?(locale) ? category : category.in_locale(locale)
      else
        category
      end
    when String
      categories.select{|c| c.name == category && (!locale || c.locale?(locale))}.first
    end
  end

end
