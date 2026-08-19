{...}: {
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "nullpointseven";
        email = "82100519+nullpointseven@users.noreply.github.com";
      };
      alias = {
        ci = "commit";
        co = "checkout";
        s = "status";
      };
    };
  };
}
