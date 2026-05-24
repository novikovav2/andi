module ApplicationHelper
  def participant_initials(name)
    name.to_s.split.map { |part| part[0] }.join.first(2).upcase
  end

  def participant_color(participant)
    colors = [
      "avatar-blue",
      "avatar-green",
      "avatar-amber",
      "avatar-purple",
      "avatar-pink",
      "avatar-cyan"
    ]

    colors[participant.id % colors.size]
  end
end
