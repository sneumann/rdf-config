# frozen_string_literal: true

class RDFConfig
  class Convert
    class Generator
      def initialize(config, convert)
        @config = config
        @convert = convert
        @reader = nil
        @converter = convert.rdf_converter

        @model = Model.instance(@config)
        @prefixes = @config.prefix.transform_values { |uri| RDF::URI.new(uri[1..-2]) }
        @prefixes[:xsd] = RDF::URI.new('http://www.w3.org/2001/XMLSchema#')

        @subject_node = {}
        @subject_names = []
        @object_names = []
        @object_triple_map = {}
      end

      private

      def generate_by_row(row)
        clear_subject_node

        #--> process_convert_variable(row)
        generate_by_subjects(row)
        generate_subject_relation
      end

      def process_convert_variable(row)
        # @converter.convert_variable_names.each do |variable_name|
        #   @converter.convert_value(row, variable_name)
        # end
      end

      def generate_by_subjects(row)
        @subject_names.each do |subject_name|
          subject_convert = @convert.subject_convert_by_name(subject_name)
          values = @converter.convert_value(row, subject_convert)
          next if values.empty?

          subject_name = subject_convert.keys.first
          values = [values] unless values.is_a?(Array)
          values.each do |subject_value|
            generate_subject(subject_name, subject_value)
          end
          generate_by_objects(subject_name, row)
        end
      end

      def generate_subject(subject_name, subject_value); end

      def generate_by_objects(subject_name, row)
        object_converts(subject_name).each do |object_convert|
          # next if @converter.converter_variable?(object_name)

          generate_by_object_convert(row, object_convert)
        end
      end

      def object_converts(subject_name)
        @convert.convert_method[:object_converts][subject_name]
      end

      def generate_by_object_convert(row, object_convert)
        values = @converter.convert_value(row, object_convert)
        values = [values] unless values.is_a?(Array)
        values.each_with_index do |value, idx|
          next if value.to_s.empty?

          triple = triple_by_object(object_convert.keys.first)
          # next if triple.nil? || triple.object.is_a?(Model::Subject)
          next if triple.nil?

          subject_name = triple.subject.name
          next unless @subject_node.key?(subject_name)

          generate_by_triple(triple, values, idx)
        end
      end

      def triple_by_object(object_name)
        unless @object_triple_map.key?(object_name)
          @object_triple_map[object_name] = @model.find_by_object_name(object_name)
        end

        @object_triple_map[object_name]
      end

      def generate_subject_relation
        @subject_node.each do |subject_name, subject_nodes|
          subject_nodes.each do |as_object_node|
            @model.find_all_by_object_name(subject_name).each do |triple|
              next unless @subject_node.key?(triple.subject.name)

              @subject_node[triple.subject.name].each do |subject_node|
                add_subject_relation(triple, subject_node, as_object_node)
              end
            end
          end
        end
      end

      def add_subject_node(subject_name, subject_node)
        @subject_node[subject_name] = [] unless @subject_node.key?(subject_name)
        @subject_node[subject_name] << subject_node
      end

      def clear_subject_node
        @subject_node.clear
      end
    end
  end
end
