# frozen_string_literal: true

class MyModuleRepositoriesController < ApplicationController
  include ApplicationHelper

  before_action :load_my_module
  before_action :load_repository, except: %i(repositories_dropdown_list repositories_list_html)
  before_action :check_my_module_view_permissions
  before_action :check_repository_view_permissions, except: %i(repositories_dropdown_list repositories_list_html)
  before_action :check_assign_repository_records_permissions, only: :update

  def index_dt
    @draw = params[:draw].to_i
    per_page = params[:length] == '-1' ? Constants::REPOSITORY_DEFAULT_PAGE_SIZE : params[:length].to_i
    page = (params[:start].to_i / per_page) + 1
    datatable_service = RepositoryDatatableService.new(@repository, params, current_user, @my_module)

    @datatable_params = {
      view_mode: params[:view_mode],
      skip_custom_columns: params[:skip_custom_columns],
      my_module: @my_module
    }
    @all_rows_count = datatable_service.all_count
    @columns_mappings = datatable_service.mappings
    @repository_rows = datatable_service.repository_rows
                                        .preload(:repository_columns,
                                                 :created_by,
                                                 repository_cells: @repository.cell_preload_includes)
                                        .page(page)
                                        .per(per_page)

    render 'repository_rows/index.json'
  end

  def update
    if params[:rows_to_assign]
      assign_service = RepositoryRows::MyModuleAssigningService.call(my_module: @my_module,
                                                                     repository: @repository,
                                                                     user: current_user,
                                                                     params: params)
    end
    if params[:rows_to_unassign]
      unassign_service = RepositoryRows::MyModuleUnassigningService.call(my_module: @my_module,
                                                                         repository: @repository,
                                                                         user: current_user,
                                                                         params: params)
    end

    if (params[:rows_to_assign].nil? || assign_service.succeed?) &&
       (params[:rows_to_unassign].nil? || unassign_service.succeed?)
      flash = update_flash_message
      status = :ok
    else
      flash = t('my_modules.repository.flash.update_error')
      status = :bad_request
    end

    respond_to do |format|
      format.json do
        render json: { flash: flash, rows_count: @my_module.repository_rows_count(@repository) }, status: status
      end
    end
  end

  def update_repository_records_modal
    modal = render_to_string(
      partial: 'my_modules/modals/update_repository_records_modal_content.html.erb',
      locals: { my_module: @my_module,
                repository: @repository,
                selected_rows: params[:selected_rows] }
    )
    render json: {
      html: modal,
      update_url: my_module_repository_path(@my_module, @repository)
    }, status: :ok
  end

  def assign_repository_records_modal
    modal = render_to_string(
      partial: 'my_modules/modals/assign_repository_records_modal_content.html.erb',
      locals: { my_module: @my_module,
                repository: @repository,
                selected_rows: params[:selected_rows] }
    )
    render json: {
      html: modal,
      update_url: my_module_repository_path(@my_module, @repository)
    }, status: :ok
  end

  def repositories_list_html
    @assigned_repositories = @my_module.assigned_repositories
    render json: { html: render_to_string(partial: 'my_modules/repositories/repositories_list') }
  end

  def full_view_table
    render json: {
      html: render_to_string(partial: 'my_modules/repositories/full_view_table')
    }
  end

  def repositories_dropdown_list
    @repositories = Repository.accessible_by_teams(current_team)

    render json: { html: render_to_string(partial: 'my_modules/repositories/repositories_dropdown_list') }
  end

  private

  def load_my_module
    @my_module = MyModule.find_by(id: params[:my_module_id])
    render_404 unless @my_module
  end

  def load_repository
    @repository = Repository.find_by(id: params[:id])
    render_404 unless @repository
  end

  def check_my_module_view_permissions
    render_403 unless can_read_experiment?(@my_module.experiment)
  end

  def check_repository_view_permissions
    render_403 unless can_read_repository?(@repository)
  end

  def check_assign_repository_records_permissions
    render_403 unless can_assign_repository_rows_to_module?(@my_module)
  end

  def update_flash_message
    assigned_count = params[:rows_to_assign]&.count
    unassigned_count = params[:rows_to_unassign]&.count

    if params[:downstream] == 'true'
      if assigned_count && unassigned_count
        t('my_modules.repository.flash.assign_and_unassign_from_task_and_downstream_html',
          assigned_items: assigned_count,
          unassigned_items: unassigned_count)
      elsif assigned_count
        t('my_modules.repository.flash.assign_to_task_and_downstream_html',
          assigned_items: assigned_count)
      elsif unassigned_count
        t('my_modules.repository.flash.unassign_from_task_and_downstream_html',
          unassigned_items: unassigned_count)
      end
    elsif assigned_count && unassigned_count
      t('my_modules.repository.flash.assign_and_unassign_from_task_html',
        assigned_items: assigned_count,
        unassigned_items: unassigned_count)
    elsif assigned_count
      t('my_modules.repository.flash.assign_to_task_html',
        assigned_items: assigned_count)
    elsif unassigned_count
      t('my_modules.repository.flash.unassign_from_task_html',
        unassigned_items: unassigned_count)
    end
  end
end