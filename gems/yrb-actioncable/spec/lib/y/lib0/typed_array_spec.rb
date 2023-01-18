# frozen_string_literal: true

RSpec.describe Y::Lib0::TypedArray do
  context "when creating a TypedArray" do
    it "creates an empty typed array" do
      ta = described_class.new

      expect(ta).to be_empty
    end

    it "creates an array of given size" do
      ta = described_class.new(2)

      expect(ta.size).to eq(2)
    end

    it "creates an array of given size filled with zeros" do
      ta = described_class.new(2)

      expect(ta).to eq([0, 0])
    end

    it "creates an array from given enumerable" do
      ta = described_class.new([1, 2])

      expect(ta).to eq([1, 2])
    end

    it "creates a view from given offset" do
      ta = described_class.new([1, 2, 3], 2)

      expect(ta).to eq([3])
    end

    it "creates a view of given length from offset" do
      ta = described_class.new([1, 2, 3], 1, 2)

      expect(ta).to eq([2, 3])
    end
  end

  context "when replacing a subarray" do
    it "replaces a part of the original array with given array" do
      ta = described_class.new([1, 0, 0, 4])
      ta.replace_with([2, 3], 1)

      expect(ta).to eq([1, 2, 3, 4])
    end
  end
end
