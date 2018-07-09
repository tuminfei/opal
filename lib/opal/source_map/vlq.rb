# Public: Base64 VLQ encoding
#
# Adopted from ConradIrwin/ruby-source_map
#   https://github.com/ConradIrwin/ruby-source_map/blob/master/lib/source_map/vlq.rb
#
# Resources
#
#   http://en.wikipedia.org/wiki/Variable-length_quantity
#   https://docs.google.com/document/d/1U1RGAehQwRypUTovF1KRlpiOFze0b-_2gc6fAH0KY0k/edit
#   https://github.com/mozilla/source-map/blob/master/lib/source-map/base64-vlq.js
#
module Opal::SourceMap::VLQ
  VLQ_BASE_SHIFT = 5
  VLQ_BASE = 1 << VLQ_BASE_SHIFT
  VLQ_BASE_MASK = VLQ_BASE - 1
  VLQ_CONTINUATION_BIT = VLQ_BASE

  BASE64_DIGITS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.split('')

  # Public: Encode a list of numbers into a compact VLQ string.
  #
  # ary - An Array of Integers
  #
  # Returns a VLQ String.
  def self.encode(ary)
    result = []
    ary.each do |n|
      vlq = n < 0 ? ((-n) << 1) + 1 : n << 1
      loop do
        digit  = vlq & VLQ_BASE_MASK
        vlq  >>= VLQ_BASE_SHIFT
        digit |= VLQ_CONTINUATION_BIT if vlq > 0
        result << BASE64_DIGITS[digit]

        break unless vlq > 0
      end
    end
    result.join
  rescue
    raise "#{$!} #{ary.inspect}"
  end

  # Public: Encode a mapping array into a compact VLQ string.
  #
  # ary - Two dimensional Array of Integers.
  #
  # Returns a VLQ encoded String seperated by , and ;.
  def self.encode_mappings(ary)
    ary.map { |group|
      group.map { |segment|
        encode(segment)
      }.join(',')
    }.join(';')
  end
end
