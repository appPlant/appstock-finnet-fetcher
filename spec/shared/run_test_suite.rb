RSpec.shared_examples '#run test suite' do |fixture, index_id, entry_count|
  let(:fetcher) { Fetcher.new }
  let(:content) { File.read File.join('spec/fixtures', fixture) }
  let(:drop_box) { fetcher.drop_box }

  before do
    @url = stub_request(:get, /inIndex=#{index_id}/i).to_return(body: content)
    allow(fetcher).to receive(:indexes).and_return [index_id]
  end

  before { fetcher.run }
  after  { FileUtils.rm_rf fetcher.drop_box }

  it { expect(@url).to have_been_requested.times(entry_count) }

  describe 'drop box' do
    let(:files) { Dir.glob("#{drop_box}/*") }

    it('should exist') { expect(File).to exist(drop_box) }
    it("should contain #{entry_count} file#{'s' if entry_count > 1}") do
      expect(files.count).to eq(entry_count)
    end

    describe 'files' do
      let(:file) { files.last }
      it('should not be empty') { expect(File).to_not be_zero(file) }
      it('should not end with empty line') do
        expect(File.open(file).readlines.last.strip.chomp).to_not be_empty
      end
    end
  end
end
