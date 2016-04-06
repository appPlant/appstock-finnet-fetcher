require 'fakefs/spec_helpers'

RSpec.describe Scraper do
  let(:base_url) { 'http://www.finanzen.net/aktien/aktien_suche.asp' }
  let(:base_params) { 'inBranche=0&inLand=0' }
  let(:search_url) { "#{base_url}?#{base_params}" }
  let(:scraper) { described_class.new }
  subject { scraper }

  it { is_expected.to respond_to(:indexes, :stocks, :linked_pages, :run) }

  describe '#follow_linked_pages?' do
    subject { scraper.follow_linked_pages? url }

    context 'aktien/aktien_suche.asp?inIndex=9' do
      let(:url) { "#{search_url}&inIndex=9" }
      it { is_expected.to be_truthy }
    end

    context 'aktien/aktien_suche.asp?inIndex=9&intpagenr=2' do
      let(:url) { "#{search_url}&inIndex=9&intpagenr=2" }
      it { is_expected.to be_falsy }
    end

    context 'UTF-8' do
      let(:url) { 'Orságos_Takar_És_Ker_BK_ON-Aktie' }
      subject { scraper }
      it { expect { scraper.follow_linked_pages? url }.to_not raise_error }
    end
  end

  context 'when the network is offline' do
    before { stub_request(:get, base_url).to_timeout }

    describe '#indexes' do
      subject { scraper.indexes }
      it { is_expected.to be_empty }
    end

    describe '#fetch' do
      before { scraper.run }

      it("should't create the file box") do
        expect(File).to_not exist(scraper.file_box)
      end
    end

    describe '#fetch(DAX)' do
      include FakeFS::SpecHelpers

      before do
        stub_request(:get, /inIndex=1/i).to_timeout
        scraper.run ['aktien/aktien_suche.asp?inIndex=1']
      end

      it('should create no files') do
        expect(Dir.entries(scraper.file_box).count).to be(2)
      end
    end
  end

  context 'when the response has wrong content' do
    let(:page) { Nokogiri::HTML('<html><body></body></html>') }

    describe '#indexes' do
      before { stub_request(:get, base_url) }
      subject { scraper.indexes }
      it { is_expected.to be_empty }
    end

    describe '#stocks' do
      subject { scraper.stocks(page) }
      it { is_expected.to be_empty }
    end

    describe '#linked_pages' do
      subject { scraper.linked_pages(page) }
      it { is_expected.to be_empty }
    end
  end

  context 'when the response has expected content' do
    let(:page) { Nokogiri::HTML(content) }

    describe '#indexes' do
      let(:content) { File.read('spec/fixtures/dax.html') }
      subject { scraper.indexes.count }
      before { stub_request(:get, base_url).to_return(body: content) }
      it { is_expected.to be(197) }
    end

    context 'DAX 30' do
      let(:content) { File.read('spec/fixtures/dax.html') }

      describe '#stocks' do
        subject { scraper.stocks(page).count }
        it { is_expected.to be(30) }
      end

      describe '#linked_pages' do
        subject { scraper.linked_pages(page) }
        it { is_expected.to be_empty }
      end
    end

    context 'NASDAQ 100' do
      let(:content) { File.read('spec/fixtures/nasdaq.html') }

      describe '#stocks' do
        subject { scraper.stocks(page).count }
        it { is_expected.to be(50) }
      end

      describe '#linked_pages' do
        subject { scraper.linked_pages(page) }
        it { is_expected.to be_any }
      end
    end
  end

  describe '#run' do
    before do
      @url = stub_request(:get, /inIndex=#{index}/i).to_return(body: content)
      allow(scraper).to receive(:indexes).and_return [index]
    end

    context 'when #indexes returns DAX only' do
      include FakeFS::SpecHelpers

      let(:content) { File.read('spec/fixtures/dax.html') }
      let(:index) { 1 }

      before { scraper.run }

      it { expect(@url).to have_been_requested }
      it('should create file box') { expect(File).to exist(scraper.file_box) }
      it('should create 1 file') do
        expect(Dir.entries(scraper.file_box).count).to be(3)
      end
    end

    context 'when #indexes returns NASDAQ only' do
      include FakeFS::SpecHelpers

      let(:content) { File.read('spec/fixtures/nasdaq.html') }
      let(:index) { 9 }

      before { scraper.run }

      it { expect(@url).to have_been_requested.times(3) }
      it('should create file box') { expect(File).to exist(scraper.file_box) }
      it('should create 3 files') do
        expect(Dir.entries(scraper.file_box).count).to be(5)
      end
    end

    context 'when called with DAX only' do
      include FakeFS::SpecHelpers

      let(:content) { File.read('spec/fixtures/dax.html') }
      let(:index) { 1 }

      before { scraper.run ["aktien/aktien_suche.asp?inIndex=#{index}"] }

      it { expect(@url).to have_been_requested }
      it('should create file box') { expect(File).to exist(scraper.file_box) }
      it('should create 1 file') do
        expect(Dir.entries(scraper.file_box).count).to be(3)
      end
    end
  end
end
