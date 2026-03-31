# frozen_string_literal: true

require "spec_helper"

RSpec.describe DockerSwarm::Middleware::ErrorHandler do
  let(:stack) { double("stack") }
  let(:middleware) { described_class.new(stack) }
  let(:env) { { response: { status: status, body: body } } }
  let(:body) { { "message" => "something went wrong" }.to_json }

  describe "#response_call" do
    context "when status is 200" do
      let(:status) { 200 }
      it "calls the stack" do
        expect(stack).to receive(:response_call).with(env)
        middleware.response_call(env)
      end
    end

    context "when status is 404" do
      let(:status) { 404 }
      it "raises NotFound" do
        expect { middleware.response_call(env) }.to raise_error(DockerSwarm::Errors::NotFound)
      end
    end

    context "when status is 429" do
      let(:status) { 429 }
      it "raises TooManyRequests" do
        expect { middleware.response_call(env) }.to raise_error(DockerSwarm::Errors::TooManyRequests)
      end
    end

    context "when status is 500" do
      let(:status) { 500 }
      it "raises InternalServerError" do
        expect { middleware.response_call(env) }.to raise_error(DockerSwarm::Errors::InternalServerError)
      end
    end
  end
end
