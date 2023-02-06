# frozen_string_literal: true

RSpec.describe Y::Actioncable::Adapter::Redis, redis: true do
  let(:key) { "document-1" }
  let(:id) { "1" }
  let(:id2) { "2" }

  it "add value" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)
      adapter.add(key, id, 1)

      actual = adapter.min(key)

      expect(actual).to eq(1)
    end
  end

  it "append value" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)
      entry_id = adapter.append(key, { id: id })

      actual = entry_id.split("-").size

      expect(actual).to eq(2)
    end
  end

  it "remove value" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)
      adapter.add(key, id, 1)
      adapter.remove(key, id)

      actual = adapter.min(key)

      expect(actual).to eq(0)
    end
  end

  it "moves value" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)
      adapter.add(key, id, 0)
      adapter.move(key, id, 1)

      actual = adapter.min(key)

      expect(actual).to eq(1)
    end
  end

  it "reads stream values" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)

      adapter.append(key, { v: 1 })
      entry_id2 = adapter.append(key, { v: 2 })
      adapter.append(key, { v: 3 })

      result = adapter.read(key, entry_id2)
      actual = result.size

      expect(actual).to eq(2)
    end
  end

  it "returns value with minimum offset" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)

      actual = adapter.min(key)

      expect(actual).to eq(0)
    end
  end

  it "truncate values lower than and equal offset" do
    with_clean_redis do
      adapter = described_class.new(Helpers::CONFIG)

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
end
