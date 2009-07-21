require 'spec/spec_helper'
require 'will_paginate/collection'

describe ThinkingSphinx::Search do
  before :each do
    @config = ThinkingSphinx::Configuration.instance
    @client = Riddle::Client.new
    
    @config.stub!(:client => @client)
    @client.stub!(:query => {:matches => [], :total_found => 41})
  end
  
  it "not request results from the client if not accessing items" do
    @config.should_not_receive(:client)
    
    ThinkingSphinx::Search.new.class
  end
  
  it "should request results if access is required" do
    @config.should_receive(:client)
    
    ThinkingSphinx::Search.new.first
  end
  
  describe '#respond_to?' do
    it "should respond to Array methods" do
      ThinkingSphinx::Search.new.respond_to?(:each).should be_true
    end
    
    it "should respond to Search methods" do
      ThinkingSphinx::Search.new.respond_to?(:per_page).should be_true
    end
  end
  
  describe '.search' do
    it "return the output of ThinkingSphinx.search" do
      @results = [] # to confirm same object
      ThinkingSphinx.stub!(:search => @results)
      
      ThinkingSphinx::Search.search.object_id.should == @results.object_id
    end
  end
  
  describe '.search_for_ids' do
    it "return the output of ThinkingSphinx.search_for_ids" do
      @results = [] # to confirm same object
      ThinkingSphinx.stub!(:search_for_ids => @results)
      
      ThinkingSphinx::Search.search_for_ids.object_id.
        should == @results.object_id
    end
  end
  
  describe '.search_for_id' do
    it "return the output of ThinkingSphinx.search_for_ids" do
      @results = [] # to confirm same object
      ThinkingSphinx.stub!(:search_for_id => @results)
      
      ThinkingSphinx::Search.search_for_id.object_id.
        should == @results.object_id
    end
  end
  
  describe '.count' do
    it "return the output of ThinkingSphinx.search" do
      @results = [] # to confirm same object
      ThinkingSphinx.stub!(:count => @results)
      
      ThinkingSphinx::Search.count.object_id.should == @results.object_id
    end
  end
  
  describe '.facets' do
    it "return the output of ThinkingSphinx.facets" do
      @results = [] # to confirm same object
      ThinkingSphinx.stub!(:facets => @results)
      
      ThinkingSphinx::Search.facets.object_id.should == @results.object_id
    end
  end
  
  describe '#populate' do
    before :each do
      @alpha_a, @alpha_b  = Alpha.new,  Alpha.new
      @beta_a, @beta_b    = Beta.new,   Beta.new
      
      @alpha_a.stub!(:id => 1); @alpha_b.stub!(:id => 2)
      @beta_a.stub!(:id => 1);  @beta_b.stub!(:id => 2)
      @client.stub! :query => {
        :matches => minimal_result_hashes(@alpha_a, @beta_b, @alpha_b, @beta_a)
      }
      Alpha.stub!(:find => [@alpha_a, @alpha_b])
      Beta.stub!(:find => [@beta_a, @beta_b])
    end
    
    it "should issue only one select per model" do
      Alpha.should_receive(:find).once.and_return([@alpha_a, @alpha_b])
      Beta.should_receive(:find).once.and_return([@beta_a, @beta_b])
      
      ThinkingSphinx::Search.new.first
    end
    
    it "should mix the results from different models" do
      search = ThinkingSphinx::Search.new
      search[0].should be_a(Alpha)
      search[1].should be_a(Beta)
      search[2].should be_a(Alpha)
      search[3].should be_a(Beta)
    end
    
    it "should maintain the Xoopit ordering for results" do
      search = ThinkingSphinx::Search.new
      search[0].id.should == 1
      search[1].id.should == 2
      search[2].id.should == 2
      search[3].id.should == 1
    end
    
    describe 'query' do
      it "should concatenate arguments with spaces" do
        @client.should_receive(:query) do |query, index, comment|
          query.should == 'two words'
        end
        
        ThinkingSphinx::Search.new('two', 'words').first
      end
      
      it "should append conditions to the query" do
        @client.should_receive(:query) do |query, index, comment|
          query.should == 'general @focused specific'
        end
        
        ThinkingSphinx::Search.new('general', :conditions => {
          :focused => 'specific'
        }).first
      end
      
      it "append multiple conditions together" do
        @client.should_receive(:query) do |query, index, comment|
          query.should match(/general.+@foo word/)
          query.should match(/general.+@bar word/)
        end
        
        ThinkingSphinx::Search.new('general', :conditions => {
          :foo => 'word', :bar => 'word'
        }).first
      end
      
      it "should apply stars if requested, and handle full extended syntax" do
        input    = %{a b* c (d | e) 123 5&6 (f_f g) !h "i j" "k l"~10 "m n"/3 @o p -(q|r)}
        expected = %{*a* b* *c* (*d* | *e*) *123* *5*&*6* (*f_f* *g*) !*h* "i j" "k l"~10 "m n"/3 @o *p* -(*q*|*r*)}
        
        @client.should_receive(:query) do |query, index, comment|
          query.should == expected
        end
        
        ThinkingSphinx::Search.new(input, :star => true).first
      end

      it "should default to /\w+/ as token for auto-starring" do
        @client.should_receive(:query) do |query, index, comment|
          query.should == '*foo*@*bar*.*com*'
        end
        
        ThinkingSphinx::Search.new('foo@bar.com', :star => true).first
      end

      it "should honour custom star tokens" do
        @client.should_receive(:query) do |query, index, comment|
          query.should == '*foo@bar.com* -*foo-bar*'
        end
        
        ThinkingSphinx::Search.new(
          'foo@bar.com -foo-bar', :star => /[\w@.-]+/u
        ).first
      end
    end
    
    describe 'comment' do
      it "should add comment if explicitly provided" do
        @client.should_receive(:query) do |query, index, comment|
          comment.should == 'custom log'
        end
        
        ThinkingSphinx::Search.new(:comment => 'custom log').first
      end
      
      it "should default to a blank comment" do
        @client.should_receive(:query) do |query, index, comment|
          comment.should == ''
        end
        
        ThinkingSphinx::Search.new.first
      end
    end
    
    describe 'match mode' do
      it "should default to :all" do
        ThinkingSphinx::Search.new.first
        
        @client.match_mode.should == :all
      end
      
      it "should default to :extended if conditions are supplied" do
        ThinkingSphinx::Search.new('general', :conditions => {
          :foo => 'word', :bar => 'word'
        }).first
        
        @client.match_mode.should == :extended
      end
      
      it "should use explicit match modes" do
        ThinkingSphinx::Search.new('general', :conditions => {
          :foo => 'word', :bar => 'word'
        }, :match_mode => :extended2).first
        
        @client.match_mode.should == :extended2
      end
    end
    
    describe 'pagination' do
      it "should set the limit using per_page" do
        ThinkingSphinx::Search.new(:per_page => 30).first
        @client.limit.should == 30
      end
      
      it "should set the offset if pagination is requested" do
        ThinkingSphinx::Search.new(:page => 3).first
        @client.offset.should == 40
      end
      
      it "should set the offset by the per_page value" do
        ThinkingSphinx::Search.new(:page => 3, :per_page => 30).first
        @client.offset.should == 60
      end
    end
    
    describe 'filters' do
      it "should filter out deleted values by default" do
        ThinkingSphinx::Search.new.first
        
        filter = @client.filters.last
        filter.values.should == [0]
        filter.attribute.should == 'sphinx_deleted'
        filter.exclude?.should be_false
      end
      
      it "should add class filters for explicit classes" do
        ThinkingSphinx::Search.new(:classes => [Alpha, Beta]).first
        
        filter = @client.filters.last
        filter.values.should == [Alpha.to_crc32, Beta.to_crc32]
        filter.attribute.should == 'class_crc'
        filter.exclude?.should be_false
      end
      
      it "should add class filters for subclasses of requested classes" do
        ThinkingSphinx::Search.new(:classes => [Person]).first
        
        filter = @client.filters.last
        filter.values.should == [
          Parent.to_crc32, Admin::Person.to_crc32,
          Child.to_crc32, Person.to_crc32
        ]
        filter.attribute.should == 'class_crc'
        filter.exclude?.should be_false
      end
      
      it "should append inclusive filters of integers" do
        ThinkingSphinx::Search.new(:with => {:int => 1}).first
        
        filter = @client.filters.last
        filter.values.should    == [1]
        filter.attribute.should == 'int'
        filter.exclude?.should be_false
      end
      
      it "should append inclusive filters of floats" do
        ThinkingSphinx::Search.new(:with => {:float => 1.5}).first
        
        filter = @client.filters.last
        filter.values.should    == [1.5]
        filter.attribute.should == 'float'
        filter.exclude?.should be_false
      end
      
      it "should append inclusive filters of booleans" do
        ThinkingSphinx::Search.new(:with => {:boolean => true}).first
        
        filter = @client.filters.last
        filter.values.should    == [true]
        filter.attribute.should == 'boolean'
        filter.exclude?.should be_false
      end
      
      it "should append inclusive filters of arrays" do
        ThinkingSphinx::Search.new(:with => {:ints => [1, 2, 3]}).first
        
        filter = @client.filters.last
        filter.values.should    == [1, 2, 3]
        filter.attribute.should == 'ints'
        filter.exclude?.should be_false
      end
      
      it "should append inclusive filters of time ranges" do
        first, last = 1.week.ago, Time.now
        ThinkingSphinx::Search.new(:with => {
          :time => first..last
        }).first
        
        filter = @client.filters.last
        filter.values.should    == (first.to_i..last.to_i)
        filter.attribute.should == 'time'
        filter.exclude?.should be_false
      end
      
      it "should append exclusive filters of integers" do
        ThinkingSphinx::Search.new(:without => {:int => 1}).first
        
        filter = @client.filters.last
        filter.values.should    == [1]
        filter.attribute.should == 'int'
        filter.exclude?.should be_true
      end
      
      it "should append exclusive filters of floats" do
        ThinkingSphinx::Search.new(:without => {:float => 1.5}).first
        
        filter = @client.filters.last
        filter.values.should    == [1.5]
        filter.attribute.should == 'float'
        filter.exclude?.should be_true
      end
      
      it "should append exclusive filters of booleans" do
        ThinkingSphinx::Search.new(:without => {:boolean => true}).first
        
        filter = @client.filters.last
        filter.values.should    == [true]
        filter.attribute.should == 'boolean'
        filter.exclude?.should be_true
      end
      
      it "should append exclusive filters of arrays" do
        ThinkingSphinx::Search.new(:without => {:ints => [1, 2, 3]}).first
        
        filter = @client.filters.last
        filter.values.should    == [1, 2, 3]
        filter.attribute.should == 'ints'
        filter.exclude?.should be_true
      end
      
      it "should append exclusive filters of time ranges" do
        first, last = 1.week.ago, Time.now
        ThinkingSphinx::Search.new(:without => {
          :time => first..last
        }).first
        
        filter = @client.filters.last
        filter.values.should    == (first.to_i..last.to_i)
        filter.attribute.should == 'time'
        filter.exclude?.should be_true
      end
      
      it "should add separate filters for each item in a with_all value" do
        ThinkingSphinx::Search.new(:with_all => {:ints => [1, 2, 3]}).first
        
        filters = @client.filters[-3, 3]
        filters.each do |filter|
          filter.attribute.should == 'ints'
          filter.exclude?.should be_false
        end
        
        filters[0].values.should == [1]
        filters[1].values.should == [2]
        filters[2].values.should == [3]
      end
      
      it "should filter out specific ids using :without_ids" do
        ThinkingSphinx::Search.new(:without_ids => [4, 5, 6]).first
        
        filter = @client.filters.last
        filter.values.should    == [4, 5, 6]
        filter.attribute.should == 'sphinx_internal_id'
        filter.exclude?.should be_true
      end
    end
    
    describe 'sort mode' do
      it "should use :relevance as a default" do
        ThinkingSphinx::Search.new.first
        @client.sort_mode.should == :relevance
      end

      it "should use :attr_asc if a symbol is supplied to :order" do
        ThinkingSphinx::Search.new(:order => :created_at).first
        @client.sort_mode.should == :attr_asc
      end

      it "should use :attr_desc if :desc is the mode" do
        ThinkingSphinx::Search.new(
          :order => :created_at, :sort_mode => :desc
        ).first
        @client.sort_mode.should == :attr_desc
      end

      it "should use :extended if a string is supplied to :order" do
        ThinkingSphinx::Search.new(:order => "created_at ASC").first
        @client.sort_mode.should == :extended
      end

      it "should use :expr if explicitly requested" do
        ThinkingSphinx::Search.new(
          :order => "created_at ASC", :sort_mode => :expr
        ).first
        @client.sort_mode.should == :expr
      end

      it "should use :attr_desc if explicitly requested" do
        ThinkingSphinx::Search.new(
          :order => "created_at", :sort_mode => :desc
        ).first
        @client.sort_mode.should == :attr_desc
      end
    end
    
    describe 'sort by' do
      it "should presume order symbols are attributes" do
        ThinkingSphinx::Search.new(:order => :created_at).first
        @client.sort_by.should == 'created_at'
      end
      
      it "replace field names with their sortable attributes" do
        ThinkingSphinx::Search.new(:order => :name, :classes => [Alpha]).first
        @client.sort_by.should == 'name_sort'
      end
      
      it "should replace field names in strings" do
        ThinkingSphinx::Search.new(
          :order => "created_at ASC, name DESC", :classes => [Alpha]
        ).first
        @client.sort_by.should == 'created_at ASC, name_sort DESC'
      end
    end
    
    describe 'max matches' do
      it "should use the global setting by default" do
        ThinkingSphinx::Search.new.first
        @client.max_matches.should == 1000
      end
      
      it "should use explicit setting" do
        ThinkingSphinx::Search.new(:max_matches => 2000).first
        @client.max_matches.should == 2000
      end
    end
    
    describe 'index weights' do
      it "should send index weights through to the client" do
        ThinkingSphinx::Search.new(:index_weights => {'foo' => 100}).first
        @client.index_weights.should == {'foo' => 100}
      end
      
      it "should convert classes to their core and delta index names" do
        ThinkingSphinx::Search.new(:index_weights => {Alpha => 100}).first
        @client.index_weights.should == {
          'alpha_core'  => 100,
          'alpha_delta' => 100
        }
      end
    end
    
    describe 'grouping' do
      it "should convert group into group_by and group_function" do
        ThinkingSphinx::Search.new(:group => :edition).first
        
        @client.group_function.should == :attr
        @client.group_by.should == "edition"
      end
      
      it "should pass on explicit grouping arguments" do
        ThinkingSphinx::Search.new(
          :group_by       => 'created_at',
          :group_function => :attr,
          :group_clause   => 'clause',
          :group_distinct => 'distinct'
        ).first
        
        @client.group_by.should       == 'created_at'
        @client.group_function.should == :attr
        @client.group_clause.should   == 'clause'
        @client.group_distinct.should == 'distinct'
      end
    end
    
    describe 'anchor' do
      it "should detect lat and lng attributes on the given model" do
        ThinkingSphinx::Search.new(
          :geo     => [1.0, -1.0],
          :classes => [Alpha]
        ).first
        
        @client.anchor[:latitude_attr].should == :lat
        @client.anchor[:longitude_attr].should == :lng
      end
      
      it "should detect lat and lon attributes on the given model" do
        ThinkingSphinx::Search.new(
          :geo     => [1.0, -1.0],
          :classes => [Beta]
        ).first
        
        @client.anchor[:latitude_attr].should == :lat
        @client.anchor[:longitude_attr].should == :lon
      end
      
      it "should detect latitude and longitude attributes on the given model" do
        ThinkingSphinx::Search.new(
          :geo     => [1.0, -1.0],
          :classes => [Person]
        ).first
        
        @client.anchor[:latitude_attr].should == :latitude
        @client.anchor[:longitude_attr].should == :longitude
      end
      
      it "should accept manually defined latitude and longitude attributes" do
        ThinkingSphinx::Search.new(
          :geo            => [1.0, -1.0],
          :classes        => [Alpha],
          :latitude_attr  => :updown,
          :longitude_attr => :leftright
        ).first
        
        @client.anchor[:latitude_attr].should == :updown
        @client.anchor[:longitude_attr].should == :leftright
      end
      
      it "should accept manually defined latitude and longitude attributes in the given model" do
        ThinkingSphinx::Search.new(
          :geo     => [1.0, -1.0],
          :classes => [Friendship]
        ).first
        
        @client.anchor[:latitude_attr].should == :person_id
        @client.anchor[:longitude_attr].should == :person_id
      end
      
      it "should accept geo array for geo-position values" do
        ThinkingSphinx::Search.new(
          :geo     => [1.0, -1.0],
          :classes => [Alpha]
        ).first
        
        @client.anchor[:latitude].should == 1.0
        @client.anchor[:longitude].should == -1.0
      end
      
      it "should accept lat and lng options for geo-position values" do
        ThinkingSphinx::Search.new(
          :lat     => 1.0,
          :lng     => -1.0,
          :classes => [Alpha]
        ).first
        
        @client.anchor[:latitude].should == 1.0
        @client.anchor[:longitude].should == -1.0
      end
    end
  end
  
  describe '#current_page' do
    it "should return 1 by default" do
      ThinkingSphinx::Search.new.current_page.should == 1
    end
    
    it "should return the requested page" do
      ThinkingSphinx::Search.new(:page => 10).current_page.should == 10
    end
  end
  
  describe '#per_page' do
    it "should return 20 by default" do
      ThinkingSphinx::Search.new.per_page.should == 20
    end
    
    it "should allow for custom values" do
      ThinkingSphinx::Search.new(:per_page => 30).per_page.should == 30
    end
    
    it "should prioritise :limit over :per_page if given" do
      ThinkingSphinx::Search.new(
        :per_page => 30, :limit => 40
      ).per_page.should == 40
    end
  end
  
  describe '#total_pages' do
    it "should calculate the total pages depending on per_page and total_entries" do
      ThinkingSphinx::Search.new.total_pages.should == 3
    end
    
    it "should allow for custom per_page values" do
      ThinkingSphinx::Search.new(:per_page => 30).total_pages.should == 2
    end
  end
  
  describe '#next_page' do
    it "should return one more than the current page" do
      ThinkingSphinx::Search.new.next_page.should == 2
    end
    
    it "should return nil if on the last page" do
      ThinkingSphinx::Search.new(:page => 3).next_page.should be_nil
    end
  end
  
  describe '#previous_page' do
    it "should return one less than the current page" do
      ThinkingSphinx::Search.new(:page => 2).previous_page.should == 1
    end
    
    it "should return nil if on the first page" do
      ThinkingSphinx::Search.new.previous_page.should be_nil
    end
  end
  
  describe '#total_entries' do
    it "should return the total number of results, not just the amount on the page" do
      ThinkingSphinx::Search.new.total_entries.should == 41
    end
  end
  
  describe '#offset' do
    it "should default to 0" do
      ThinkingSphinx::Search.new.offset.should == 0
    end
    
    it "should increase by the per_page value for each page in" do
      ThinkingSphinx::Search.new(:per_page => 25, :page => 2).offset.should == 25
    end
  end
  
  describe '.each_with_groupby_and_count' do
    before :each do
      @alpha = Alpha.new
      @alpha.stub!(:id => 1)
      
      @client.stub! :query => {
        :matches => [{
          :attributes => {
            'sphinx_internal_id' => @alpha.id,
            'class_crc'          => Alpha.to_crc32,
            '@groupby'           => 101,
            '@count'             => 5
          }
        }]
      }
      Alpha.stub!(:find => [@alpha])
    end
    
    it "should yield the match, group and count" do
      search = ThinkingSphinx::Search.new
      search.each_with_groupby_and_count do |obj, group, count|
        obj.should    == @alpha
        group.should  == 101
        count.should  == 5
      end
    end
  end
  
  describe '.each_with_weighting' do
    before :each do
      @alpha = Alpha.new
      @alpha.stub!(:id => 1)
      
      @client.stub! :query => {
        :matches => [{
          :attributes => {
            'sphinx_internal_id' => @alpha.id,
            'class_crc'          => Alpha.to_crc32
          }, :weight => 12
        }]
      }
      Alpha.stub!(:find => [@alpha])
    end
    
    it "should yield the match and weight" do
      search = ThinkingSphinx::Search.new
      search.each_with_weighting do |obj, weight|
        obj.should    == @alpha
        weight.should == 12
      end
    end
  end
  
  describe '.each_with_*' do
    before :each do
      @alpha = Alpha.new
      @alpha.stub!(:id => 1)
      
      @client.stub! :query => {
        :matches => [{
          :attributes => {
            'sphinx_internal_id' => @alpha.id,
            'class_crc'          => Alpha.to_crc32,
            '@geodist'           => 101,
            '@groupby'           => 102,
            '@count'             => 103
          }, :weight => 12
        }]
      }
      Alpha.stub!(:find => [@alpha])
      
      @search = ThinkingSphinx::Search.new
    end
    
    it "should yield geodist if requested" do
      @search.each_with_geodist do |obj, distance|
        obj.should      == @alpha
        distance.should == 101
      end
    end
    
    it "should yield count if requested" do
      @search.each_with_count do |obj, count|
        obj.should    == @alpha
        count.should  == 103
      end
    end
    
    it "should yield groupby if requested" do
      @search.each_with_groupby do |obj, group|
        obj.should    == @alpha
        group.should  == 102
      end
    end
    
    it "should still use the array's each_with_index" do
      @search.each_with_index do |obj, index|
        obj.should   == @alpha
        index.should == 0
      end
    end
  end
end

describe ThinkingSphinx::Search, "playing nice with Search model" do
  it "should not conflict with models called Search" do
    lambda { Search.find(:all) }.should_not raise_error
  end
end