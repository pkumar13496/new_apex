public class CLS_ApprovalProcessUtility {
    
    public static id getRM(string userlevel,string uid,string module){
       map<id,user> mapuser=new map<id,user>([select id,Role_Category_Level__c,managerid from user where IsActive = true]);
            user loggedinuser=mapuser.get(userinfo.getUserId());
            user BM;
            user RM;
            
            if(userlevel=='Level 7'){
                 BM=mapuser.get(loggedinuser.managerid);
                 RM=mapuser.get(BM.managerid);
                
            }else if(userlevel=='Level 6'){
                 RM=mapuser.get(loggedinuser.managerid);
                
            }
        return RM.id; 
    }
    
    
    public static id getDVP(string userlevel,string uid,string module){
        
         map<id,user> mapuser=new map<id,user>([select id,Role_Category_Level__c,managerid from user where IsActive = true]);
            user loggedinuser=mapuser.get(userinfo.getUserId());
            user BM;
            user RM;
            
            if(userlevel=='Level 7'){
                 BM=mapuser.get(loggedinuser.managerid);
                 RM=mapuser.get(BM.managerid);
                
            }else if(userlevel=='Level 6'){
                 RM=mapuser.get(loggedinuser.managerid);
                
            }
         user DVP=mapuser.get(RM.managerid);
        return DVP.id;
        
    }
    public static void getDirector(){
        
    }
    public static string getAsigneeuser(string queuename,boolean applyRoundRobin){
        List<Group> queues = [
                SELECT Id,
                    (Select Id, UserOrGroupId FROM GroupMembers Order By ID ASC)
                FROM Group
                Where Type = 'Queue'AND DeveloperName = :queuename
        ];
       
            L1_Operations_RR__c lrr = L1_Operations_RR__c.getOrgDefaults();
        Integer userIndex = (lrr.get('User_Index__c') == null || Integer.valueOf(lrr.get('User_Index__c')) < -1) 
            ? -1 : Integer.valueOf(lrr.get('User_Index__c'));
          if (queues.size() > 0 && queues.get(0).GroupMembers.size() > 0) {
            Id queueId = queues.get(0).Id;
            Integer groupMemberSize = queues.get(0).GroupMembers.size();
           
                    Integer leadUserIndex =  (userIndex + 1) >= groupMemberSize ? 0 : userIndex + 1;                   
                    userIndex = leadUserIndex;
               lrr.User_Index__c = userIndex;
            update lrr;
                return queues.get(0).GroupMembers.get(leadUserIndex).UserOrGroupId;
                
            }
        else {
            return null;
        }

            // Update the custom settings user index with the last lead assigned user
           
        
    }

}