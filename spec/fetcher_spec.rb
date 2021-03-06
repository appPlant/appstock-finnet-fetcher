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
  end

  context 'when the network is offline' do
    before { stub_request(:get, base_url).to_timeout }

    describe '#indexes' do
      subject { fetcher.indexes }
      it { is_expected.to be_empty }
    end

    describe '#fetch' do
      subject { fetcher.run }
      it { is_expected.to be_empty }
    end
  end

  context 'when the response has wrong content' do
    let(:page) { Nokogiri::HTML('<html><body></body></html>') }

    before { stub_request(:get, base_url) }

    describe '#indexes' do
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

    describe '#fetch' do
      subject { fetcher.run }
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

      describe '#run' do
        before do
          allow(fetcher).to receive(:indexes).and_return([1])
          @url    = stub_request(:get, /inIndex=1/i).to_return(body: content)
          @stocks = fetcher.run
        end

        it { expect(@url).to have_been_requested }
        it('should return 30') { expect(@stocks.count).to eq(30) }
        it('should return valid URI schemes') do
          expect { URI(@stocks.first) }.to_not raise_error
        end
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
end
