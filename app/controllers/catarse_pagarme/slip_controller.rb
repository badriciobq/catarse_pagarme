require 'weekdays'

module CatarsePagarme
  class SlipController < CatarsePagarme::ApplicationController

    include ApplicationHelper

    def create
      transaction = SlipTransaction.new(slip_attributes, payment).charge!

      render json: { boleto_url: transaction.boleto_url, payment_status: transaction.status }
    rescue PagarMe::PagarMeError => e
      render json: { boleto_url: nil, payment_status: 'failed', message: e.message }
    end

    def update
      transaction = SlipTransaction.new(slip_attributes, payment).charge!
      respond_to do |format|
        format.html { redirect_to transaction.boleto_url }
        format.json do
          { boleto_url: transaction.boleto_url }
        end
      end
    end

    protected

    def slip_attributes
      {
        payment_method: 'boleto',
        boleto_expiration_date: payment.slip_expiration_date,
        amount: delegator.value_for_transaction,
        postback_url: feop_criar_index_url( host: "criar.feop.com.br",
                                            subdomain: "",
                                            protocol: CatarsePagarme.configuration.protocol
        ),
        customer: {
          email: payment.user.email,
          name: payment.user.name
        },
        metadata: metadata_attributes
      }
    end
  end
end
