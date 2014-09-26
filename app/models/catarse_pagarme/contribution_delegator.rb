module CatarsePagarme
  class ContributionDelegator
    attr_accessor :contribution, :transaction

    def initialize(contribution)
      configure_pagarme
      self.contribution = contribution
    end

    def change_status_by_transaction(transactin_status)
      case transactin_status
      when 'paid', 'authorized' then
        self.contribution.confirm unless self.contribution.confirmed?
      when 'refunded' then
        self.contribution.refund unless self.contribution.refunded?
      when 'refused' then
        self.contribution.cancel unless self.contribution.canceled?
      when 'waiting_payment', 'processing' then
        self.contribution.waiting unless self.contribution.waiting_confirmation?
      end
    end

    def refund
      if contribution.is_credit_card?
        transaction.refund
      else
        transaction.refund(bank_account_attributes)
      end
    end

    def value_for_transaction
      (self.contribution.value * 100).to_i
    end

    def value_with_installment_tax(installment)
      current_installment = get_installment(installment)

      if current_installment.present?
        current_installment['amount']
      else
        value_for_transaction
      end
    end

    def transaction
      @transaction ||= ::PagarMe::Transaction.find_by_id(self.contribution.payment_id)
    end

    def get_installment(installment_number)
      installment = get_installments['installments'].select do |installment|
        !installment[installment_number.to_s].nil?
      end

      installment[installment_number.to_s]
    end

    def get_installments
      @installments ||= PagarMe::Transaction.calculate_installments({
        amount: self.value_for_transaction,
        interest_rate: CatarsePagarme.configuration.interest_rate
      })
    end

    def get_fee(payment_method)
      if payment_method == PaymentType::SLIP
        CatarsePagarme.configuration.slip_tax
      else
        (self.contribution.value * CatarsePagarme.configuration.credit_card_tax.to_f) + CatarsePagarme.configuration.credit_card_cents_fee
      end
    end

    protected

    def bank_account_attributes
      bank = contribution.user.bank_account

      {
        bank_account: {
          bank_code: (bank.bank_code || bank.name),
          agencia: bank.agency,
          agencia_dv: bank.agency_digit,
          conta: bank.account,
          conta_dv: bank.account_digit,
          legal_name: bank.user_name,
          document_number: bank.user_document
        }
      }
    end

    def configure_pagarme
      ::PagarMe.api_key = CatarsePagarme.configuration.api_key
    end
  end
end
