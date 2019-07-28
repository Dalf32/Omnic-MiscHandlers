# VersionNumber
#
# AUTHOR::  Kyle Mullins

class VersionNumber
  include Comparable

  def self.valid?(version_str)
    parts = version_str.split('.')
    return false unless parts.count.between?(2, 5)

    return false if parts.any? { |p| /\D/.match?(p) }

    true
  end

  def self.from_str(version_str)
    VersionNumber.new(*version_str.split('.').map(&:to_i))
  end

  def initialize(major_ver, minor_ver, major_patch = 0, minor_patch = 0,
                 revision = 0)
    @major_version = major_ver
    @minor_version = minor_ver
    @major_patch_num = major_patch
    @minor_patch_num = minor_patch
    @revision_num = revision
  end

  def <=>(other)
    version_parts.zip(other.version_parts).map { |(v1, v2)| v1 <=> v2 }
                 .find(&:nonzero?) || 0
  end

  def -(other)
    num_parts = [trimmed_parts.count, other.trimmed_parts.count].min
    part_adjust = [1000, 100, 10, 1, 0.0001]
    subset_parts(num_parts).zip(other.subset_parts(num_parts))
                           .zip(part_adjust)
                           .map { |((p1, p), adj)| (p1 - p) * adj }.sum
  end

  def to_s
    trimmed_parts.join('.')
  end

  protected

  def version_parts
    [@major_version, @minor_version, @major_patch_num,
     @minor_patch_num, @revision_num]
  end

  def trimmed_parts
    version_parts.reverse.drop_while(&:zero?).reverse
  end

  def subset_parts(num_parts)
    version_parts[0..(num_parts - 1)]
  end
end
