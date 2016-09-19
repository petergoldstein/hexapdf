# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # The 'post' table contains information for using a font on a PostScript printer.
        #
        # post format 2.5 is currently not implemented because use of the format is deprecated since
        # 2000 in the specification and no font with a format 2.5 post subtable was available for
        # testing.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6post.html
        class Post < Table

          # The format of the table (a Rational).
          attr_accessor :format

          # The italic angle (a Rational).
          attr_accessor :italic_angle

          # The suggested distance of the top of the underline from the baseline (negative values
          # indicate underlines below the baseline).
          attr_accessor :underline_position

          # The suggested thickness for underlines.
          attr_accessor :underline_thickness

          # Specifies whether the font is proportional (value is 0) or monospaced (value is not 0).
          attr_accessor :is_fixed_pitch

          # Returns +true+ if the font is monospaced.
          #
          # See: #is_fixed_pitch
          def is_fixed_pitch?
            @is_fixed_pitch != 0
          end

          # Minimum memory usage when a font is downloaded.
          attr_accessor :min_mem_type42

          # Maximum memory usage when a font is downloaded.
          attr_accessor :max_mem_type42

          # Minimum memory usage when a Type1 font is downloaded.
          attr_accessor :min_mem_type1

          # Maximum memory usage when a Type1 font is downloaded.
          attr_accessor :max_mem_type1

          # Returns the name for the given glpyh id or ".notdef" if the given glyph id has no name.
          def [](glyph_id)
            @glyph_names[glyph_id] || '.notdef'.freeze
          end

          private

          def parse_table #:nodoc:
            @format = read_fixed
            @italic_angle = read_fixed
            @underline_position, @underline_thickness, @is_fixed_pitch, @min_mem_type42,
              @max_mem_type42, @min_mem_type1, @max_mem_type1 = read_formatted(24, 's>2N5')

            sub_table_length = directory_entry.length - 32
            @glyph_names = case @format
                           when 1 then Format1.parse(io, sub_table_length)
                           when 2 then Format2.parse(io, sub_table_length)
                           when 3 then Format3.parse(io, sub_table_length)
                           when 4 then Format4.parse(io, sub_table_length)
                           else
                             raise HexaPDF::Error, "Unsupported TTF post table format: #{@format}"
                           end
          end

          def load_default #:nodoc:
            @format = 1.to_r
            @italic_angle = 0.to_r
            @underline_position = @underline_thickness = @is_fixed_pitch = @min_mem_type42 =
              @max_mem_type42 = @min_mem_type1 = @max_mem_type1 = 0
            @glyph_names = {}
          end


          # 'post' table format 1
          module Format1

            # The 258 predefined glyph names in the standard Macintosh ordering.
            GLYPH_NAMES = %w[
              .notdef .null nonmarkingreturn space exclam quotedbl numbersign dollar percent
              ampersand quotesingle parenleft parenright asterisk plus comma hyphen period slash
              zero one two three four five six seven eight nine colon semicolon less equal greater
              question at A B C D E F G H I J K L M N O P Q R S T U V W X Y Z bracketleft backslash
              bracketright asciicircum underscore grave a b c d e f g h i j k l m n o p q r s t u v
              w x y z braceleft bar braceright asciitilde Adieresis Aring Ccedilla Eacute Ntilde
              Odieresis Udieresis aacute agrave acircumflex adieresis atilde aring ccedilla eacute
              egrave ecircumflex edieresis iacute igrave icircumflex idieresis ntilde oacute ograve
              ocircumflex odieresis otilde uacute ugrave ucircumflex udieresis dagger degree cent
              sterling section bullet paragraph germandbls registered copyright trademark acute
              dieresis notequal AE Oslash infinity plusminus lessequal greaterequal yen mu
              partialdiff summation product pi integral ordfeminine ordmasculine Omega ae oslash
              questiondown exclamdown logicalnot radical florin approxequal Delta guillemotleft
              guillemotright ellipsis nonbreakingspace Agrave Atilde Otilde OE oe endash emdash
              quotedblleft quotedblright quoteleft quoteright divide lozenge ydieresis Ydieresis
              fraction currency guilsinglleft guilsinglright fi fl daggerdbl periodcentered
              quotesinglbase quotedblbase perthousand Acircumflex Ecircumflex Aacute Edieresis
              Egrave Iacute Icircumflex Idieresis Igrave Oacute Ocircumflex apple Ograve Uacute
              Ucircumflex Ugrave dotlessi circumflex tilde macron breve dotaccent ring cedilla
              hungarumlaut ogonek caron Lslash lslash Scaron scaron Zcaron zcaron brokenbar Eth eth
              Yacute yacute Thorn thorn minus multiply onesuperior twosuperior threesuperior onehalf
              onequarter threequarters franc Gbreve gbreve Idotaccent Scedilla scedilla Cacute
              cacute Ccaron ccaron dcroat
            ].freeze

            # :call-seq:
            #   Format1.parse(io, length)    -> glyph_names
            #
            # Returns the array containing the 258 predefined glpyh names.
            def self.parse(_io, _length)
              GLYPH_NAMES
            end

          end


          # 'post' table format 2
          module Format2

            # :call-seq:
            #   Format2.parse(io, length)    -> glyph_names
            #
            # Parses the format 2 post subtable from the given IO at the current position and
            # returns the contained glyph name map.
            def self.parse(io, length)
              end_pos = io.pos + length
              num_glyphs = io.read(2).unpack('n').first
              glyph_name_index = io.read(2 * num_glyphs).unpack('n*')
              names = []
              names << io.read(io.getbyte).force_encoding(::Encoding::UTF_8) while io.pos < end_pos
              mapper(glyph_name_index, names)
            end

            def self.mapper(glyph_name_index, names) #:nodoc:
              lambda do |glyph_id|
                name_index = glyph_name_index[glyph_id]
                if !name_index
                  nil
                elsif name_index <= 257
                  Format1::GLYPH_NAMES[name_index]
                else
                  names[name_index - 258]
                end
              end
            end

          end


          # 'post' table format 3
          module Format3

            # :call-seq:
            #   Format3.parse(io, length)    -> glyph_names
            #
            # Since the post table format 3 does not contain any valid glyph names, an empty array
            # is returned.
            def self.parse(_io, _length)
              [].freeze
            end

          end


          # 'post' table format 4
          module Format4

            # :call-seq:
            #   Format4.parse(io, length)    -> glyph_names
            #
            # Parses the format 4 post subtable from the given IO at the current position and
            # returns a lambda mapping the glyph id to a character code.
            def self.parse(io, length)
              mapper(io.read(length).unpack('n*'))
            end

            def self.mapper(char_codes) #:nodoc:
              lambda {|glyph_id| char_codes[glyph_id] || 0xFFFF }
            end

          end

        end

      end
    end
  end
end
