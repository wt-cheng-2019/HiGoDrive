module Api
  module V0
    class UsersController < ApplicationController
      include UsersHelper

      before_action :set_user, only: [:show, :getpos, :forgot_password,
        :reset_password, :peak]
      before_action :set_current_user, only: [:update, :setpos,
        :user_tasks, :tasks_engaging, :tasks_history, :driver_info,
        :upload_license, :accept_license, :reject_license,
        :unprocessed_licenses]
      # ----------
      before_action :validate_init_params, only: [:create]
      before_action :validate_update_params, only: [:update]
      before_action :validate_forgotpwd_params, only: [:forgot_password]
      before_action :validate_resetpwd_params, only: [:reset_password]

      BioMaxLen = 2000

      # GET /users
      # GET /users.json
      def index
        render json: {size: User.count}, status: :ok
      end

      # GET /users/1
      # GET /users/1.json
      def show
        render json: @user.public_json_info, status: :ok
      end

      # GET /users/search/:username
      def peak
        render json: {uid: @user.id.to_s}, status: :ok
      end

      # POST /checkusername
      def checkusername
        _username = user_init_params[:username] || ''
        return bad_request unless _username.length.between?(3, 20)
        render json: {'message': User.username_exist?(_username)}
      end

      # POST /checkphone
      def checkphone
        number = Util.format_phone_number(params[:phone]) || ''
        return bad_request unless number.match(User::PhoneRegex)
        render json: {'message': User.phone_exist?(number)}
      end

      # POST /checkemail
      def checkemail
        _email = user_init_params[:email] || ''
        return bad_request unless _email.length.between?(3, 255)
        render json: {'message': User.email_exist?(_email)}
      end

      # POST /users
      # POST /users.json
      def create
        @user = User.new(user_init_params)
        respond_to do |format|
          if @user.save
            # dirty hack to auto login
            session[:user_id] = @user.id
            # -----
            format.html do
              if RoleManager.match?(params[:roles].to_i, :driver)
                redirect_to '/signup/driver', notice: 'Please upload your licenses'
              else
                redirect_to '/', notice: 'User was successfully created.'
              end
            end
            format.json { render json: {message: 'created'}, status: :created}
          else
            format.html { unprocessable_entity }
            format.json { render json: @user.errors, status: :unprocessable_entity }
          end
        end
      end

      # PATCH/PUT /users/1
      # PATCH/PUT /users/1.json
      def update
        @user.update(user_update_fields)
        redirect_to '/user'
      end

      # DELETE /users/1
      # DELETE /users/1.json
      def destroy
        not_acceptable
      end

      # POST /user/setpos
      def setpos
        _params = user_pos_params
        lat, lng = _params[:lat], _params[:lng]
        return bad_request unless coordinates_ok?(lat, lng)
        @user.set_pos(lat, lng)
        return_ok
      end

      # GET /user/getpos
      def getpos
        render json: @user.get_pos, status: :ok
      end

      # POST /forgotpassword
      def forgot_password
        token = @user.generate_reset_token(params["authenticity_token"])
        UserMailer.reset_email(request.domain, @user, token).deliver!
        redirect_to '/'
      end

      # POST /resetpassword
      def reset_password
        @user.reset_password(user_reset_fields)
        redirect_to '/'
      end

      # GET /mytasks
      def user_tasks
        render json: @user.tasks.collect{|t| t.id}, status: :ok
      end

      # GET /tasks_engaging
      def tasks_engaging
        render json: @user.tasks_engaging || [], status: :ok
      end

      # GET /tasks_history
      def tasks_history
        render json: @user.all_tasks || [], status: :ok
      end

      # POST /upload_license
      def upload_license
        return unprocessable_entity if @user.licensed?
        @user.update(driver_license_params)
        $unlicensed_drivers << @user.id
        PushNotificationsController.send_license_uploaded(@user)
        return_ok
      end

      # POST /accept_license
      def accept_license
        return forbidden unless RoleManager.match?(@user.roles, :admin)
        target = User.find(params[:id])
        return not_found unless target
        return bad_request if target.licensed? || target.driver_license.nil?
        $unlicensed_drivers.delete(target.id)
        target.accept_license
        PushNotificationsController.send_license_accepted(target)
        redirect_to '/'
      end

      # POST /reject_license
      def reject_license
        return forbidden unless RoleManager.match?(@user.roles, :admin)
        target = User.find(params[:id])
        return not_found unless target
        $unlicensed_drivers.delete(target.id)
        target.revoke_license
        PushNotificationsController.send_license_rejected(target)
        return_ok
      end

      # GET /driver_info/:uid
      def driver_info
        return unauthorized if RoleManager.match?(@user.roles, :admin)
        target = User.find(params[:id])
        return not_found unless target
        render json: target.driver_json_info, status: :ok
      end

      # GET /unprocessed_licenses
      def unprocessed_licenses
        return forbidden unless RoleManager.match?(@user.roles, :admin)
        ret = User.find($unlicensed_drivers).collect{|u| u.driver_json_info}
        render json: ret, status: :ok
      end

      private
      # Use callbacks to share common setup or constraints between actions.
      def set_user
        @user = User.wide_query(user_find_params.compact.first)
        not_found if @user.nil?
      end

      def set_current_user
        @user = current_user
        unauthorized if @user.nil?
      end

      def validate_init_params
        return bad_request unless register_param_ok?(user_init_params)
        return forbidden unless Util.email_deliverable?(user_init_params[:email])
        return unprocessable_entity unless driver_licensed?
        return true
      end

      def validate_update_params
        return unauthorized if @user.nil?
        return unsupported_media_type unless avatar_url_ok?(params[:avatar_url])
        return unprocessable_entity unless password_change_ok?(params)
        return forbidden if (params[:bio] || '').length > BioMaxLen
        return true
      end

      def validate_resetpwd_params
        tme = @user.forgot_timestamp || 0
        return bad_request if logged_in?
        return unprocessable_entity if tme == 0
        # return gone if Time.now - tme > ForgotDuration
        return unauthorized if params[:token] != @user.password_reset_token
        return unprocessable_entity unless password_reset_ok?(params)
        return true
      end

      def validate_forgotpwd_params
        return bad_request if logged_in?
        # return gone if Time.now - (@user.forgot_timestamp || 0) < ForgotDuration
        return unauthorized if @user.username != params[:username]
        return unauthorized if @user.email != params[:email]
        return true
      end

      def avatar_url_ok?(aurl)
        return true if aurl.nil?
        return SupportedAvatarFormat.include?(aurl.split('.').last.downcase)
      end

      def password_change_ok?(_params)
        oldpwd = _params[:old_password]
        newpwd = _params[:password]
        conpwd = _params[:password_confirmation]
        return true unless oldpwd || newpwd || conpwd
        return false if !newpwd || !conpwd
        return false if newpwd != conpwd
        return false unless @user.authenticate(oldpwd)
        return true
      end

      def password_reset_ok?(_params)
        newpwd = _params[:password]
        conpwd = _params[:password_confirmation]
        return false if !newpwd || !conpwd
        return false if newpwd != conpwd
        return true
      end

      def register_param_ok?(params)
        return false if UserInitParms.any?{|k| params[k].nil?}
        return true
      end

      def driver_licensed?
        return true
      end

      def coordinates_ok?(lat, lng)
        x = Float(lng) rescue nil
        y = Float(lat) rescue nil
        return x && y
      end

      def user_url
        "/home"
      end

    end # class
  end
end
