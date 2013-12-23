require 'zip/zip'

module Parcel
  module Interfaces

    class ZipFileInterface < ScratchSpaceBase
      File = Struct.new(:name, :size)

      def initialize(*args)
        super
        options[:extension] ||= "zip"
      end

      # Returns all the files present in the repository.
      def contents
        return [] unless @scratch.exist?("original")

        result = Array.new
        Zip::ZipFile.foreach(@scratch.path("original")) { |entry| result << File.new(entry.name, entry.size) }
        result
      end
    
      # Returns the contents of the given file. Supports wildcard matching, 
      # in which case returns the contents of the first file found.
      def read_file(filename)
        return nil unless @scratch.exist?("original")

        if filename =~ /[\*\?]/         
          file_match = Regexp.new("^" + filename.gsub(".", "\\.").gsub("*", ".*").gsub("?", ".") + "$", Regexp::IGNORECASE)

          Zip::ZipFile.foreach(@scratch.path('original')) do |entry|
            if entry.name =~ file_match
              return @scratch.fetch("extracted_#{entry.name}") do |dest|
                entry.get_input_stream { |src| FileUtils.copy_stream src, dest }
              end
            end
          end

          return nil
        else
          if @scratch.exist?("extracted_#{filename}")
            return @scratch.read("extracted_#{filename}")
          end

          Zip::ZipFile.open( @scratch.path('original') ) do |reader|
            if entry = reader.find_entry(filename)
              return @scratch.fetch("extracted_#{entry.name}") do |dest|
                entry.get_input_stream { |src| FileUtils.copy_stream src, dest }
              end
            else
              return nil
            end
          end
        end
      end

      def add_file(filename, contents_or_stream)
        @scratch.delete("extracted_#{filename}")
        ZipRuby::Archive.open( @scratch.path('original'), ZipRuby::CREATE ) do |writer|
          exist = ( 0...writer.num_files ).collect{ |index| writer.get_name(index) }.include?(filename)
          if contents_or_stream.respond_to?(:read)
            exist ? writer.replace_io( filename, contents_or_stream) : writer.add_io( filename , contents_or_stream)
          else
            exist ? writer.replace_buffer(filename, contents_or_stream) : writer.add_buffer( filename, contents_or_stream)
          end
        end
        modified!
      end
    end

  end
end

Parcel.register_interface :zip, Parcel::Interfaces::ZipFileInterface
