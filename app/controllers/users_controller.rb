class UsersController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create, :destroy]

  def create
    Events::User::Created.create(payload: user_params)
  end

  def destroy
    Events::User::Destroyed.create(user_id: user_params[:id], payload: user_params)
  end

  private def user_params
    params.require(:user).permit(:name, :email, :password, :id)
  end
end
