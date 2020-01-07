class PagesController < ApplicationController
  def index
    return home if logged_in?
    render 'welcome'
  end

  def home
    return index unless logged_in?
    render 'main'
  end

  def login
    return home if logged_in?
    render 'login'
  end

  def signup
    return home if logged_in?
    render 'signup'
  end

  def driverSignup
    return home if logged_in?
    render 'driverSignup'
  end

  def passwordForget
  end

  def passwordReset
  end

  def search
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'search'
  end

  def task
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'task'
  end

  def report
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'report'
  end

  def userInfo
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'userInfo'
  end

  def editAccount
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'editAccount'
  end

  def changePassword
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'changePassword'
  end

  def editUserBio
    flash.now[:danger] = 'Please log in first' unless logged_in?
    return login unless logged_in?
    render 'editUserBio'
  end

  def admin
    # TODO: LOGIN CHECK
    # flash.now[:danger] = 'Please log in as administrator' unless logged_in?
    # return login unless logged_in?
    render 'admin'
  end
end
