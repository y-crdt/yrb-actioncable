# frozen_string_literal: true

RSpec.describe Y::Actioncable::Adapter::Test do
  let(:key) { "document-1" }
  let(:id) { "1" }
  let(:id2) { "2" }

  it "add value" do
    adapter = described_class.new
    adapter.add(key, id, 1)

    actual = adapter.min(key)

    expect(actual).to eq(1)
  end

  it "remove value" do
    adapter = described_class.new
    adapter.add(key, id, 1)
    adapter.remove(key, id)

    actual = adapter.min(key)

    expect(actual).to eq(0)
  end

  it "moves value" do
    adapter = described_class.new
    adapter.add(key, id, 0)
    adapter.move(key, id, 1)

    actual = adapter.min(key)

    expect(actual).to eq(1)
  end

  it "reads stream values" do
    adapter = described_class.new

    adapter.append(key, { v: 1 })
    entry_id2 = adapter.append(key, { v: 2 })
    adapter.append(key, { v: 3 })

    result = adapter.read(key, entry_id2)
    actual = result.size

    expect(actual).to eq(2)
  end

  it "returns value with minimum offset" do
    adapter = described_class.new

    actual = adapter.min(key)

    expect(actual).to eq(0)
  end

  it "truncate values lower than and equal offset" do
    adapter = described_class.new

    adapter.append(key, { v: 1 })
    adapter.append(key, { v: 2 })
    entry_id3 = adapter.append(key, { v: 3 })

    adapter.truncate(key, entry_id3)
    result = adapter.read(key)

    # [ ["1675692001-2", value] ]
    #     ^_______________
    actual = result.first&.first

    expect(actual).to eq(entry_id3)
  end
end
