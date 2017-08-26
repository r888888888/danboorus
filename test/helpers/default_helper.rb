module DefaultHelper
  def setup
    super
    CurrentUser.test!(FactoryGirl.create(:admin_user))
    Booru.current = FactoryGirl.create(:booru)    
  end

  def teardown
    super
    Booru.current = nil
    CurrentUser.clear!
  end
end
