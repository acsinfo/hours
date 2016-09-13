module CSVDownload
  def send_csv(name:, hours_entries:)
    send_data(
      EntryCSVGenerator.generate(hours_entries),
      filename: "#{name}-entries-#{DateTime.now}.csv",
      type: "text/csv"
    )
  end
end
