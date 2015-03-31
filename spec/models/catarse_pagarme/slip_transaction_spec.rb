require 'spec_helper'

describe CatarsePagarme::SlipTransaction do
  let(:payment) { create(:payment, value: 100) }
  let(:pagarme_transaction_attributes) {
    {
      id: 'abcd',
      charge: true,
      status: 'paid',
      boleto_url: 'boleto url',
      installments: 1,
      acquirer_name: 'pagarme',
      tid: '123123',
      card_brand: nil
    }
  }

  let(:pagarme_transaction) {
    double(pagarme_transaction_attributes)
  }

  let(:valid_attributes) do
    {
      slip_payment: {
        payment_method: 'boleto',
        amount: payment.pagarme_delegator.value_for_transaction,
        postback_url: 'http://test.foo'
      }, user: {
        bank_account_attributes: {
          bank_id: 1, agency: '1', agency_digit: '1',
          account: '1', account_digit: '1', owner_name: 'foo',
          owner_document: 'bar'
        }
      }
    }
  end

  let(:invalid_attributes) do
    {
      slip_payment: {
        payment_method: 'boleto',
        amount: payment.pagarme_delegator.value_for_transaction,
        postback_url: 'http://test.foo'
      }, user: {
        bank_account_attributes: {
          owner_name: ''
        }
      }
    }
  end

  let(:slip_transaction) { CatarsePagarme::SlipTransaction.new(valid_attributes, payment) }

  before do
    PagarMe::Transaction.stub(:new).and_return(pagarme_transaction)
    pagarme_transaction.stub(:to_json).and_return(pagarme_transaction_attributes.to_json)
    CatarsePagarme::PaymentDelegator.any_instance.stub(:change_status_by_transaction).and_return(true)
  end

  context "#user" do
    subject { slip_transaction.user }
    it { expect(subject).to eq(payment.user) }
  end

  context "#charge!" do
    context "with invalid attributes" do
      let(:slip_transaction) {
        CatarsePagarme::SlipTransaction.new(invalid_attributes, payment)
      }

      it "should raises an error" do
        expect {
          slip_transaction.charge!
        }.to raise_error(PagarMe::PagarMeError)
      end
    end

    context "with valid attributes" do
      before do
        slip_transaction.should_receive(:update_user_bank_account).and_call_original
        slip_transaction.user.should_receive(:update_attributes).and_return(true)
        payment.should_receive(:update_attributes).at_least(1).and_call_original
        PagarMe::Transaction.should_receive(:find_by_id).with(pagarme_transaction.id).and_return(pagarme_transaction)
        CatarsePagarme::PaymentDelegator.any_instance.should_receive(:change_status_by_transaction).with('paid')

        slip_transaction.charge!
        payment.reload
      end

      it "should update payment payment_id" do
        expect(payment.gateway_id).to eq('abcd')
      end

      it "should update payment payment_service_fee" do
        expect(payment.gateway_fee).to eq(0.0)
      end

      it "should update payment payment_method" do
        expect(payment.gateway).to eq('Pagarme')
      end

      it "should update payment slip_url" do
        expect(payment.gateway_data["boleto_url"]).to eq('boleto url')
      end

      it "should update payment payment_choice" do
        expect(payment.payment_method).to eq(CatarsePagarme::PaymentType::SLIP)
      end

      it "should update payment acquirer_name" do
        expect(payment.gateway_data["acquirer_name"]).to eq('pagarme')
      end

      it "should update payment acquirer_tid" do
        expect(payment.gateway_data["acquirer_tid"]).to eq('123123')
      end

      it "should update payment installment_value" do
        expect(payment.installment_value).to_not be_nil
      end
    end
  end

end
