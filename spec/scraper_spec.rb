
RSpec.describe Scraper do
  let(:base_url) { 'http://www.finanzen.net/aktien/aktien_suche.asp' }
  let(:base_params) { 'inBranche=0&inLand=0' }
  let(:search_url) { "#{base_url}?#{base_params}" }
  let(:scraper) { described_class.new }
  subject { scraper }

  it { is_expected.to respond_to(:run) }

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

  context 'network timeout' do
    before { stub_request(:any, base_url).to_timeout }

    describe '#indexes' do
      subject { scraper.indexes }
      it { is_expected.to be_empty }
    end
  end

  context 'bad content' do
    let(:page) { Nokogiri::HTML('<html><body></body></html>') }

    describe '#indexes' do
      before { stub_request(:any, base_url) }
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

  context 'good content' do
    let(:page) { Nokogiri::HTML(content) }

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
end
