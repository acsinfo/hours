describe Hour do
  describe "validations" do
    it { should validate_presence_of :user }
    it { should validate_presence_of :project }
    it { should validate_presence_of :category }
    it { should validate_presence_of :starting_time }
  end

  describe "associations" do
    it { should belong_to :project }
    it { should belong_to :category }
    it { should belong_to :user }
    it { should have_many :taggings }
    it { should have_many :tags }
  end

  it "is audited" do
    hour = create(:hour)
    user = create(:user)

    Audited.audit_class.as_user(user) do
      hour.update_attribute(:value, 2)
    end

    expect(hour.audits.last.user).to eq(user)
  end

  describe "#tag_list" do
    it "returns a string of comma separated values" do
      hour = create(:hour, description: "#omg #hashtags")
      expect(hour.tag_list).to eq("omg, hashtags")
    end
  end

  describe "tags from the description" do
    let(:hour) { build(:hour) }

    it "parses the tags from the description" do
      hour.description = "Did some #opensource #scala, mostly for #research"
      hour.save
      expect(hour.tags.size).to eq(3)
      expect(hour.tag_list).to eq("opensource, scala, research")
    end

    it "removes any tagging that is left out" do
      hour.description = "#hashtags!"
      hour.save
      hour.description = "#omgomg"
      hour.save
      expect(hour.tag_list).to eq("omgomg")
    end

    it "updates the tag when the casing changes" do
      hour.description = "did some #tdd"
      hour.save
      expect {
        hour.description = "did some #TDD"
        hour.save
      }.to_not raise_error
      expect(Tag.last.name).to eq("TDD")
      expect(hour.reload.tag_list).to include("TDD")
    end
  end

  describe "#by_last_created_at" do
    it "orders the entries by created_at" do
      create(:hour)
      Timecop.scale(600)
      last_hour = create(:hour)
      expect(Hour.by_last_created_at.first).to eq(last_hour)
    end
  end

  describe "#by_starting_time" do
    it "orders the entries by starting_time (latest first)" do
      create(:hour, starting_time: Time.new(2014, 01, 01, 8, 0, 0))
      latest = create(:hour, starting_time: Time.new(2014, 02, 02, 12, 0, 0))
      create(:hour, starting_time: Time.new(2014, 02, 02, 8, 0, 0))

      expect(Hour.by_starting_time.first).to eq(latest)
    end
  end

  it "#with_clients" do
    client = create(:client)
    create(:hour)
    create(:hour).project.update_attribute(:client, client)

    expect(Hour.with_clients.count).to eq(1)
  end

  it "#open_per_user" do
    entry_1 = create(:hour, ending_time: 5.days.ago)
    entry_2 = create(:hour)
    user = entry_1.user
    entry_3 = create(:hour, user: user)
    
    expect(Hour.open_per_user(user.id)).to eq([entry_3])
  end

  describe "#query" do
    let(:entry_1) { create(:hour, starting_time: 5.days.ago) }
    let(:entry_2) { create(:hour, starting_time: 4.days.ago) }
    let(:entry_3) { create(:hour, starting_time: 3.days.ago) }
    let(:entry_4) { create(:hour, starting_time: 2.days.ago) }
    let(:entry_5) { create(:hour, starting_time: 1.day.ago) }

    before(:each) do
      Timecop.freeze DateTime.new(2015, 4, 20)
      [entry_1, entry_2, entry_3, entry_4, entry_5]
    end

    it "queries by date" do
      entry_filter = {}
      entry_filter[:from_date] = "17/04/2015"
      entry_filter[:to_date] = "20/04/2015"
      entries = Hour.query(entry_filter)
      expect(entries).to include(entry_3, entry_4, entry_5)
    end
  end

  describe "#search_by_description" do
    before do
      @entry_1 = create(:hour, description: "protocol LVP1000")
      @entry_2 = create(:hour, description: "protocol ASP1000")
    end

    it "filters entries by search key" do
      entries = Hour.search_by_description("ASP1000")
      expect(entries).to_not include(@entry_1)
      expect(entries).to include(@entry_2)
    end
  
    it "retrieves all the entries that match search key" do
      entries = Hour.search_by_description("protocol")
      expect(entries).to include(@entry_1)
      expect(entries).to include(@entry_2)
    end

    it "is not case sensitive" do
      entries = Hour.search_by_description("asp1000")
      expect(entries).to_not include(@entry_1)
      expect(entries).to include(@entry_2)
    end

    it "does not filter by substring" do
      entries = Hour.search_by_description("ASP")
      expect(entries).to_not include(@entry_2)
    end
  end
end
