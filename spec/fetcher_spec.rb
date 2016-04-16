require 'fakefs/spec_helpers'

RSpec.describe Fetcher do
  let(:base_url) { 'http://www.finanzen.net/aktien/aktien_suche.asp' }
  let(:base_params) { 'inBranche=0&inLand=0' }
  let(:search_url) { "#{base_url}?#{base_params}" }
  let(:fetcher) { described_class.new }
  subject { fetcher }

  it { is_expected.to respond_to(:indexes, :stocks, :linked_pages, :run) }

  describe '#follow_linked_pages?' do
    subject { fetcher.follow_linked_pages? url }

    context 'when its the head of the list' do
      let(:url) { "#{search_url}&inIndex=9" }
      it { is_expected.to be_truthy }
    end

    context 'when its the tail of the list' do
      let(:url) { "#{search_url}&inIndex=9&intpagenr=2" }
      it { is_expected.to be_falsy }
    end

    context 'UTF-8' do
      let(:url) { 'Orságos_Takar_És_Ker_BK_ON-Aktie' }
      subject { fetcher }
      it { expect { fetcher.follow_linked_pages? url }.to_not raise_error }
    end
  end

  context 'when the network is offline' do
    before { stub_request(:get, base_url).to_timeout }

    describe '#indexes' do
      subject { fetcher.indexes }
      it { is_expected.to be_empty }
    end

    describe '#fetch' do
      before { fetcher.run }

      it("should't create the drop box") do
        expect(File).to_not exist(fetcher.drop_box)
      end
    end

    describe '#fetch(DAX)' do
      include FakeFS::SpecHelpers

      before do
        stub_request(:get, /inIndex=1/i).to_timeout
        fetcher.run ['aktien/aktien_suche.asp?inIndex=1']
      end

      it('should create no files') do
        expect(Dir.entries(fetcher.drop_box).count).to eq(2)
      end
    end
  end

  context 'when the response has wrong content' do
    let(:page) { Nokogiri::HTML('<html><body></body></html>') }

    describe '#indexes' do
      before { stub_request(:get, base_url) }
      subject { fetcher.indexes }
      it { is_expected.to be_empty }
    end

    describe '#stocks' do
      subject { fetcher.stocks(page) }
      it { is_expected.to be_empty }
    end

    describe '#linked_pages' do
      subject { fetcher.linked_pages(page) }
      it { is_expected.to be_empty }
    end
  end

  context 'when the response has expected content' do
    let(:page) { Nokogiri::HTML(content) }

    describe '#indexes' do
      let(:content) { File.read('spec/fixtures/dax.html') }
      subject { fetcher.indexes.count }
      before { stub_request(:get, base_url).to_return(body: content) }
      it { is_expected.to eq(197) }
    end

    context 'DAX 30' do
      let(:content) { File.read('spec/fixtures/dax.html') }

      describe '#stocks' do
        subject { fetcher.stocks(page).count }
        it { is_expected.to eq(30) }
      end

      describe '#linked_pages' do
        subject { fetcher.linked_pages(page) }
        it { is_expected.to be_empty }
      end
    end

    context 'NASDAQ 100' do
      let(:content) { File.read('spec/fixtures/nasdaq.html') }

      describe '#stocks' do
        subject { fetcher.stocks(page).count }
        it { is_expected.to eq(50) }
      end

      describe '#linked_pages' do
        subject { fetcher.linked_pages(page) }
        it { is_expected.to be_any }
      end
    end
  end

  describe '#run' do
    before do
      @url = stub_request(:get, /inIndex=#{index}/i).to_return(body: content)
      allow(fetcher).to receive(:indexes).and_return [index]
    end

    context 'when #indexes returns DAX only' do
      include FakeFS::SpecHelpers

      let(:content) { File.read('spec/fixtures/dax.html') }
      let(:index) { 1 }

      before { fetcher.run }

      it { expect(@url).to have_been_requested }
      it('should create drop box') { expect(File).to exist(fetcher.drop_box) }
      it('should create 1 file') do
        expect(Dir.entries(fetcher.drop_box).count).to eq(3)
      end
    end

    context 'when #indexes returns NASDAQ only' do
      include FakeFS::SpecHelpers

      let(:content) { File.read('spec/fixtures/nasdaq.html') }
      let(:index) { 9 }

      before { fetcher.run }

      it { expect(@url).to have_been_requested.times(3) }
      it('should create drop box') { expect(File).to exist(fetcher.drop_box) }
      it('should create 3 files') do
        expect(Dir.entries(fetcher.drop_box).count).to eq(5)
      end
    end

    context 'when called with DAX only' do
      include FakeFS::SpecHelpers

      let(:content) { File.read('spec/fixtures/dax.html') }
      let(:index) { 1 }

      before { fetcher.run ["aktien/aktien_suche.asp?inIndex=#{index}"] }

      it { expect(@url).to have_been_requested }
      it('should create drop box') { expect(File).to exist(fetcher.drop_box) }
      it('should create 1 file') do
        expect(Dir.entries(fetcher.drop_box).count).to eq(3)
      end
    end
  end
end
