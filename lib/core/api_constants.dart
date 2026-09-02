/// Endpoints da API do Workut.
///
/// Espelha o `AppConstants.ts` do workutFront para que app e web
/// consumam exatamente os mesmos recursos.
class ApiConstants {
  static const String baseServer =
      'https://workutapi-ewfaggdga2aaeghx.austriaeast-01.azurewebsites.net';

  static const String login = '$baseServer/api/Login/v1';
  static const String users = '$baseServer/api/Users/v1';
  static const String files = '$baseServer/api/File/v1';
  static const String home = '$baseServer/api/Homes/v1';

  static const String feedPosts = '$baseServer/api/FeedPosts/v1';
  static const String feedPostsWorkout = '$feedPosts/workout';
  static const String postLikes = '$baseServer/api/PostLikes/v1';
  static const String postComments = '$baseServer/api/PostComments/v1';

  static const String myFriends = '$baseServer/api/MyFriends/v1';
  static const String friendRequests = '$baseServer/api/FriendRequests/v1';

  static const String exercises = '$baseServer/api/Exercises/v1';
  static const String exerciseSeries = '$baseServer/api/ExerciseSeries/v1';
  static const String exerciseBySeries = '$baseServer/api/ExerciseBySeries/v1';
  static const String exerciseDaillys = '$baseServer/api/ExerciseDaillys/v1';

  static const String myTestimonies = '$baseServer/api/MyTestimonies/v1';
  static const String testimonyLikes = '$baseServer/api/TestimonyLikes/v1';
  static const String myScraps = '$baseServer/api/MyScraps/v1';
  static const String userProfileCores = '$baseServer/api/UserProfileCores/v1';
  static const String notifications = '$baseServer/api/Notifications/v1';

  /// Avatar exibido quando o usuário ainda não enviou foto.
  static const String defaultAvatar =
      'https://www.buritama.sp.leg.br/imagens/parlamentares-2013-2016/sem-foto.jpg/image';
}
