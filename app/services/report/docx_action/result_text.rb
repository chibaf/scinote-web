# frozen_string_literal: true

# rubocop:disable  Style/ClassAndModuleChildren
module Report::DocxAction::ResultText
  def draw_result_text(result, children)
    result_text = result.result_text
    timestamp = result.created_at
    @docx.p
    @docx.p do
      text result.name
      text ' ' + I18n.t('search.index.archived'), color: 'a0a0a0' if result.archived?
      text ' '
      text I18n.t('projects.reports.elements.result_table.user_time',
                  timestamp: I18n.l(timestamp, format: :full), user: result.user.full_name), color: 'a0a0a0'
    end
    html = custom_auto_link(result_text.text, team: @report_team)
    html_to_word_converter(html)

    children.each do |result_hash|
      draw_result_comments(result, result_hash['sort_order']) if result_hash['type_of'] == 'result_comments'
    end
  end
end
# rubocop:enable  Style/ClassAndModuleChildren
