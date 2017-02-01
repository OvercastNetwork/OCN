Repository.define do
    repositories provider: :github, namespace: 'OvercastNetwork' do
        visible? true do
            repository :plugins do
                title           "ProjectAres"
                description     "Our custom Bukkit plugins (such as PGM) that control matches and add network features to Minecraft"
                repo            "ProjectAres"
                open?           true
            end

            repository :sportbukkit do
                title           "SportBukkit"
                description     "Our open source fork of Bukkit that is finely tuned for competitive Minecraft"
                repo            "SportBukkit"
                open?           true
            end

            repository :docs do
                title           "docs.oc.tc"
                description     "The documentation website for PGM mapmakers at https://docs.oc.tc"
                repo            "docs.oc.tc"
                open?           true
            end
        end
    end
end
