require 'erb'
require 'puppet'
require 'helpers'

module Puppet
  class Retrospec
    attr_reader :included_declarations
    attr_reader :classes_and_defines
    attr_reader :module_name
    attr_reader :modules_included
    attr_accessor :default_path
    attr_accessor :files
    attr_accessor :default_modules


    def modules_included
      if @modules_included.nil?
        @modules_included = default_modules + referenced_modules
      end
      @modules_included
    end

    def referenced_modules
      []
    end

    def module_name
      @module_name ||= Helpers.get_module_name
    end

    def initialize(path="manifests/**/*.pp")
      @default_path = path
      @default_modules = ['stdlib']
      classes_and_defines
      included_declarations
      module_name
      modules_included
    end

    def files
      if @files.nil?
        @files = Dir[@default_path]

      end
      @files
    end

    def self.run
      spec = Retrospec.new
      spec.safe_create_spec_helper
      spec.safe_create_rakefile
      spec.safe_create_fixtures_file
      spec.safe_create_resource_spec_files
      spec.safe_make_shared_context

    end


    def classes_and_defines(filepaths=files)
        @classes_and_defines = []
        filepaths.each do |file|
          resources = []
          p = Puppet::Parser::Lexer.new
          p.string = File.read(file)
          tokens = p.fullscan
          tokens.index do | token|
            if [:CLASS, :DEFINE].include? token.first
              k = tokens.index { |token| [:NAME].include? token.first }
              resources.push({:type_name => token.last[:value] , :name => tokens[k].last[:value] })
            end
          end
          @classes_and_defines.push({:filename => File.basename(file, '.pp'), :types => resources })
        end
      return @classes_and_defines
    end

    def included_declarations(filepaths=files)
        @included_declarations = {}
        filepaths.each do |file|
          includes = []
          p = Puppet::Parser::Lexer.new
          p.string = File.read(file)
          tokens = p.fullscan
          k = 0
          typename = nil
          tokens.each do | token|

            next if not token.last.is_a?(Hash)
            if typename.nil? and [:CLASS, :DEFINE].include? token.first
              j = tokens.index { |token| [:NAME].include? token.first }
              typename = tokens[j].last[:value]
            end
            if token.last.fetch(:value, nil) == 'include'
              key = token.last[:value]
              value = tokens[k + 1].last[:value]
              includes << value
            end
            k = k + 1

          end
          @included_declarations[typename] = includes

        end
      return @included_declarations
    end


    def self.safe_make_shared_context(template='templates/shared_context.erb')
      safe_create_template_file('spec/shared_contexts.rb', template)
    end

    # Gets all the classes and define types from all the files in the manifests directory
    # Creates an associated spec file for each type and even creates the subfolders for nested classes one::two::three
    def safe_create_resource_spec_files(template='templates/resource-spec_file.erb', enable_sub_folders=false)
      classes_dir = 'spec/classes'
      defines_dir = 'spec/defines'
      Helpers.safe_mkdir('spec/classes')
      Helpers.safe_mkdir('spec/defines')
      @classes_and_defines.each do |value|
        types = value[:types]
        types.each do |type|
          # run template
          tokens = type[:name].split('::')
          if tokens.length > 2
            dir_name = tokens.pop.join('/')
          end
          if type[:type_name] == 'class'
            type_dir_name = "spec/classes"
          else
            type_dir_name = "spec/defines"
          end
          if enable_sub_folders
            self.safe_mkdir("#{type_dir_name}/#{dir_name}")
          end
          file_name = tokens.last
          safe_create_template_file("#{type_dir_name}/#{file_name}_spec.rb", template)

        end

      end
    end

    def safe_create_fixtures_file(template='templates/fixtures_file.erb')
      safe_create_template_file('.fixtures.yml', template)
    end

    def safe_create_spec_helper(template='templates/spec_helper_file.erb')
      safe_create_template_file('spec/spec_helper.rb', template)
    end

    def safe_create_template_file(path, template)
      File.open(template) do |file|
        renderer = ERB.new(file.read, 0, '>')
        content = renderer.result binding
        Helpers.safe_create_file(path, content)
      end

    end



  end
end